const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("LPYieldStaking", function () {
    let token, treasuryToken;
    let user1, user2;
    let mockContract;
    const stakingTokenSupply = 1000;
    const treasuryAmount = 5000000;
    const user2Stake = 200;
    const user1Stake = stakingTokenSupply - user2Stake;
    const minStakingAmount = 100;
    const lockupPeriod = 0;

    // Helper function to deploy a new TokenLock instance
    async function deployTokenLock(startTimestampOffset, endTimestampOffset, rewards, lockupPeriod) {
        const MockUniswapV3 = await ethers.getContractFactory("MockUniswapV3PositionManager");
        mockContract = await MockUniswapV3.deploy();

        const TokenLock = await ethers.getContractFactory("LPYieldStaking");
        const now = Math.floor(Date.now() / 1000);

        return await TokenLock.deploy(
            treasuryToken.getAddress(),
            now + startTimestampOffset,
            now + endTimestampOffset,
            rewards,
            token.getAddress(),
            treasuryToken.getAddress(),
            mockContract.getAddress(),
            lockupPeriod
        );
    }

    beforeEach(async function () {
        await ethers.provider.send("hardhat_reset", []);
        // Get signers
        [user1, user2] = await ethers.getSigners();

        // Deploy mock ERC20 tokens
        const Token = await ethers.getContractFactory("ERC20Token");
        token = await Token.deploy("Token", "TKN", stakingTokenSupply, user1.address);
        treasuryToken = await Token.deploy("TreasuryToken", "TREAS", treasuryAmount, user1.address);

        // Transfer some tokens to user2
        await token.transfer(user2.address, user2Stake);
    });

    describe("LP Yield Staking token locking", function () {
        let tokenLock;
        let uniswapManagerMock;

        it("should prevent non-owner from unstaking NFT", async function () {
            // Deploy and initialize
            tokenLock = await deployTokenLock(100, 10100, treasuryAmount, 0);
            
            const tokenId = 1;
            const liquidity = ethers.parseUnits("800", 18);
            await mockContract.setPosition(tokenId, treasuryToken.getAddress(), token.getAddress(), liquidity);
            
            // User1 stakes
            await tokenLock.connect(user1).stake(tokenId);
            
            // User2 tries to unstake User1's NFT
            await expect(tokenLock.connect(user2).unstake(tokenId))
                .to.be.revertedWith("Only initial owner of NFT token can unstake");
        });

        it("should enforce lockup period for staked NFTs", async function () {
            const oneDay = 24 * 60 * 60;
            const lockPeriod = oneDay * 7; // 7 days lockup
            
            // Deploy with 7 day lockup
            const TokenLock = await ethers.getContractFactory("LPYieldStaking");
            const now = Math.floor(Date.now() / 1000);
            tokenLock = await deployTokenLock(100, 10100, treasuryAmount, lockPeriod);

            const tokenId = 1;
            const liquidity = ethers.parseUnits("800", 18);
            await mockContract.setPosition(tokenId, treasuryToken.getAddress(), token.getAddress(), liquidity);
            
            // Stake NFT
            await tokenLock.stake(tokenId);
            
            // Try to unstake before lockup period
            await expect(tokenLock.unstake(tokenId))
                .to.be.revertedWith("Token lockup period hasn't passed");

            // Move time forward past lockup period
            await ethers.provider.send("evm_increaseTime", [lockPeriod + 1]);
            await ethers.provider.send("evm_mine");

            // Should now be able to unstake
            await expect(tokenLock.unstake(tokenId)).to.not.be.reverted;
        });

        it("should accept NFT with inverted token order", async function () {
            tokenLock = await deployTokenLock(100, 10100, treasuryAmount, 0);
            
            const tokenId = 1;
            const liquidity = ethers.parseUnits("800", 18);
            
            // Set position with inverted token order (token1 first, token0 second)
            await mockContract.setPosition(tokenId, token.getAddress(), treasuryToken.getAddress(), liquidity);
            
            // Should not revert when staking
            await expect(tokenLock.stake(tokenId)).to.not.be.reverted;
            
            // Verify staking worked
            expect(await tokenLock.totalStaked()).to.be.eq(liquidity);
            expect(await tokenLock.nftOwner(tokenId)).to.be.eq(user1.address);
        });

        it("should reject NFT with invalid tokens", async function () {
            tokenLock = await deployTokenLock(100, 10100, treasuryAmount, 0);
            
            const tokenId = 1;
            const liquidity = ethers.parseUnits("800", 18);
            
            // Deploy a different token for testing
            const InvalidToken = await ethers.getContractFactory("ERC20Token");
            const invalidToken = await InvalidToken.deploy("Invalid", "INV", 1000000, user1.address);
            
            // Set position with invalid token combination
            await mockContract.setPosition(tokenId, invalidToken.getAddress(), token.getAddress(), liquidity);
            
            // Should revert when staking with invalid lpStakingToken1
            await expect(tokenLock.stake(tokenId))
                .to.be.revertedWith("Invalid lpStakingToken2 token");
                
            // Set position with another invalid combination
            await mockContract.setPosition(tokenId, token.getAddress(), invalidToken.getAddress(), liquidity);
            
            // Should revert when staking with invalid lpStakingToken2
            await expect(tokenLock.stake(tokenId))
                .to.be.revertedWith("Invalid lpStakingToken2 token");
        });

        it("should calculate rewards for multiple users correctly", async function () {
            // Deploy and initialize
            tokenLock = await deployTokenLock(100, 10100, treasuryAmount, 0);
            await treasuryToken.approve(tokenLock.getAddress(), treasuryAmount);
            await tokenLock.depositTreasuryTokens();

            const tokenId = 1;  // Example tokenId
            const liquidity = ethers.parseUnits("800", 18)
            // Call setPosition
            await mockContract.setPosition(tokenId, treasuryToken.getAddress(), token.getAddress(), liquidity);

            // Owner stakes
            await tokenLock.stake(tokenId);

            expect(await tokenLock.totalStaked()).to.be.eq(liquidity);
            expect(await tokenLock.userStake(owner.address)).to.be.eq(liquidity);
            expect(await tokenLock.nftOwner(tokenId)).to.be.eq(owner.address);
            expect((await tokenLock.getLockedNfts(owner.address))[0]).to.be.eq(tokenId);

            const rewardsRate = BigInt(treasuryAmount) / BigInt(10000);
            const initialTimestamp = (await ethers.provider.getBlock("latest")).timestamp;

            // Simulate time passage
            const halfPeriod = 5000;
            await ethers.provider.send("evm_increaseTime", [halfPeriod]);
            await ethers.provider.send("evm_mine");

            const firstHalfTimestamp = (await ethers.provider.getBlock("latest")).timestamp; // Updated block timestamp
            const elapsedTime = BigInt(firstHalfTimestamp - initialTimestamp - 100); // Calculate elapsed time dynamically

            // Expected rewardsPerToken calculation
            const firstUserStake = BigInt(liquidity);
            const expectedRewardsPerToken = (rewardsRate * elapsedTime * BigInt(1e18)) / firstUserStake;

            // Get actual rewardsPerToken from the contract
            const actualRewardsPerToken = await tokenLock.currentRewardsPerToken();

            expect(BigInt(actualRewardsPerToken)).to.be.closeTo(expectedRewardsPerToken, 50);

            const expectedOwnerReward = (rewardsRate * elapsedTime * BigInt(user1Stake)) / BigInt(user1Stake);

            const user2TokenId = 2;  // Example tokenId
            const user2Liquidity = ethers.parseUnits("200", 18)
            // Call setPosition
            await mockContract.connect(user2).setPosition(user2TokenId, treasuryToken.getAddress(), token.getAddress(), user2Liquidity);
            // User2 stakes later
            await tokenLock.connect(user2).stake(user2TokenId);

            // Try to stake invalid NFT
            const invalitTokenId = 3;
            await expect(tokenLock.stake(invalitTokenId))
                .to.be.revertedWith("No liquidity in NFT");

            // Simulate more time passage
            await ethers.provider.send("evm_increaseTime", [halfPeriod + 100]);
            await ethers.provider.send("evm_mine");

            const currentTimestamp = (await ethers.provider.getBlock("latest")).timestamp;
            const elapsedTimeUser1 = BigInt(currentTimestamp - firstHalfTimestamp); // Time since User1 staked

            const totalStaked = BigInt(user1Stake + user2Stake);

            const expectedUser1RewardFinal =
                (rewardsRate * elapsedTimeUser1 * BigInt(user1Stake)) / totalStaked + expectedOwnerReward;

            const elapsedTimeUser2 = BigInt(currentTimestamp - firstHalfTimestamp); // Time since User1 staked

            const expectedUser2Reward = (rewardsRate * elapsedTimeUser2 * BigInt(user2Stake)) / totalStaked;

            // Get actual rewards from the contract
            const actualUser1Reward = await tokenLock.currentUserRewards(user1.address);
            const actualUser2Reward = await tokenLock.currentUserRewards(user2.address);

            // // Log rewards for debugging
            console.log("Expected User1 Reward:", expectedUser1RewardFinal.toString());
            console.log("Actual User1 Reward:", actualUser1Reward.toString());
            console.log("Expected User2 Reward:", expectedUser2Reward.toString());
            console.log("Actual User2 Reward:", actualUser2Reward.toString());

            // Use a tolerance to account for rounding differences due to inconsistencies in block calculations
            const tolerance = BigInt(1e5);
            expect(BigInt(actualUser1Reward)).to.be.closeTo(expectedUser1RewardFinal, tolerance);
            expect(BigInt(actualUser2Reward)).to.be.closeTo(expectedUser2Reward, tolerance);

            // Verify balances after claim
            await tokenLock.claim();
            await tokenLock.connect(user2).claim();

            await expect(await tokenLock.currentUserRewards(user1.address)).to.equal(0);

            const ownerBalance = await treasuryToken.balanceOf(user1.address);
            const user1Balance = await treasuryToken.balanceOf(user2.address);

            expect(BigInt(ownerBalance)).to.be.closeTo(actualUser1Reward, tolerance);
            expect(BigInt(user1Balance)).to.be.closeTo(actualUser2Reward, tolerance);

            // Unstake tokens
            await tokenLock.unstake(tokenId);
            await expect(await mockContract.tokenOwner(tokenId)).to.equal(owner.address);

            await tokenLock.connect(user2).unstake(user2TokenId);
            await expect(await mockContract.tokenOwner(user2TokenId)).to.equal(user2.address);
        });

        it("should implement IERC721Receiver correctly", async function () {
            tokenLock = await deployTokenLock(100, 10100, treasuryAmount, 0);
            
            // The selector for onERC721Received is bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))
            const expectedSelector = "0x150b7a02";
            
            // Call onERC721Received directly
            const result = await tokenLock.onERC721Received(
                user1.address, // operator
                user2.address, // from
                1, // tokenId
                "0x" // data
            );
            
            // Verify the returned selector matches the interface
            expect(result).to.equal(expectedSelector);
        });
    });
});

describe("LPYieldStaking", function () {
    let LPYieldStaking, MockERC20, MockPositionManager;
    let staking, token1, token2, rewardsToken, positionManager;
    let owner, user1, user2;
    let rewardsStart, rewardsEnd;

    const rewardsPeriod = 100;
    const TOTAL_REWARDS = "1000";
    const LOCKUP_PERIOD = 86400; // 1 day in seconds

    beforeEach(async function () {
        [owner, user1, user2] = await ethers.getSigners();

        // Deploy mock tokens
        MockERC20 = await ethers.getContractFactory("MockERC20");
        token1 = await (await MockERC20.deploy("LP Token 1", "LP1")).waitForDeployment();
        token2 = await (await MockERC20.deploy("LP Token 2", "LP2")).waitForDeployment();
        rewardsToken = await (await MockERC20.deploy("Rewards Token", "RWD")).waitForDeployment();

        // Deploy mock position manager
        MockPositionManager = await ethers.getContractFactory("MockUniswapV3PositionManager");
        positionManager = await (await MockPositionManager.deploy()).waitForDeployment();

        // Set up timestamps
        const latestBlock = await ethers.provider.getBlock("latest");
        rewardsStart = latestBlock.timestamp + rewardsPeriod;
        rewardsEnd = rewardsStart + rewardsPeriod;

        LPYieldStaking = await ethers.getContractFactory("LPYieldStaking");
    });

    describe("Constructor", function () {
        it("Should set the correct initial values", async function () {
            staking = await (await LPYieldStaking.deploy(
                rewardsToken,
                rewardsStart,
                rewardsEnd,
                TOTAL_REWARDS,
                token1,
                token2,
                positionManager,
                LOCKUP_PERIOD
            )).waitForDeployment();

            expect(await staking.rewardsToken()).to.equal(await rewardsToken.getAddress());
            expect(await staking.rewardsStart()).to.equal(rewardsStart);
            expect(await staking.rewardsEnd()).to.equal(rewardsEnd);
            expect(await staking.totalLocked()).to.equal(TOTAL_REWARDS);
            expect(await staking.lpStakingToken1()).to.equal(await token1.getAddress());
            expect(await staking.lpStakingToken2()).to.equal(await token2.getAddress());
            expect(await staking.positionManager()).to.equal(await positionManager.getAddress());
            expect(await staking.lockupPeriod()).to.equal(LOCKUP_PERIOD);
        });

        it("Should revert if rewards token is zero address", async function () {
            await expect(
                LPYieldStaking.deploy(
                    ethers.ZeroAddress, // zero address for rewards token
                    rewardsStart,
                    rewardsEnd,
                    TOTAL_REWARDS,
                    token1,
                    token2,
                    positionManager,
                    LOCKUP_PERIOD
                )
            ).to.be.revertedWith("Rewards token cannot be zero address");
        });

        it("Should revert if rewards end is before rewards start", async function () {
            await expect(
                LPYieldStaking.deploy(
                    rewardsToken,
                    rewardsStart,
                    rewardsStart - 1, // end before start
                    TOTAL_REWARDS,
                    token1,
                    token2,
                    positionManager,
                    LOCKUP_PERIOD
                )
            ).to.be.revertedWith("Rewards end must be after rewards start");
        });

        it("Should revert if total rewards is zero", async function () {
            await expect(
                LPYieldStaking.deploy(
                    rewardsToken,
                    rewardsStart,
                    rewardsEnd,
                    0, // zero rewards
                    token1,
                    token2,
                    positionManager,
                    LOCKUP_PERIOD
                )
            ).to.be.revertedWith("Total rewards must be greater than zero");
        });

        it("Should revert if position manager is zero address", async function () {
            await expect(
                LPYieldStaking.deploy(
                    rewardsToken,
                    rewardsStart,
                    rewardsEnd,
                    TOTAL_REWARDS,
                    token1,
                    token2,
                    ethers.ZeroAddress,
                    LOCKUP_PERIOD
                )
            ).to.be.revertedWith("Position manager cannot be zero address");
        });

        it("Should revert if LP tokens are the same", async function () {
            await expect(
                LPYieldStaking.deploy(
                    rewardsToken,
                    rewardsStart,
                    rewardsEnd,
                    TOTAL_REWARDS,
                    token1,
                    token1,
                    positionManager,
                    LOCKUP_PERIOD
                )
            ).to.be.revertedWith("LP tokens must be different");
        });

        describe("Treasury Token Deposit", function () {
            beforeEach(async function () {
                staking = await (await LPYieldStaking.deploy(
                    rewardsToken,
                    rewardsStart,
                    rewardsEnd,
                    TOTAL_REWARDS,
                    token1,
                    token2,
                    positionManager,
                    LOCKUP_PERIOD
                )).waitForDeployment();
                await rewardsToken.mint(owner.address, TOTAL_REWARDS);
                await rewardsToken.approve(staking.getAddress(), TOTAL_REWARDS);
            });

            it("Should revert depositTreasuryTokens when called by non-owner", async function () {
                await expect(
                    staking.connect(user1).depositTreasuryTokens()
                ).to.be.revertedWithCustomError(staking, "OwnableUnauthorizedAccount")
                 .withArgs(user1.address);
            });

            it("Should revert if staking period has already started", async function () {
                // Move time past rewards start
                await ethers.provider.send("evm_increaseTime", [rewardsPeriod + 1]);
                await ethers.provider.send("evm_mine");

                await expect(
                    staking.depositTreasuryTokens()
                ).to.be.revertedWith("Can't deposit treasury tokens if staking period has started");
            });
        });
    });
});
