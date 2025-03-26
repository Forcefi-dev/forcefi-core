const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Erc20YieldStaking", function () {
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
    async function deployTokenLock(startTimestampOffset, endTimestampOffset, rewards) {
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

        it("should calculate rewards for multiple users correctly", async function () {
            // Deploy and initialize
            tokenLock = await deployTokenLock(100, 10100, treasuryAmount);
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

            expect(BigInt(actualRewardsPerToken)).to.be.closeTo(expectedRewardsPerToken, 10);

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

            // Use a tolerance to account for rounding differences
            const tolerance = BigInt(1e4);
            expect(BigInt(actualUser1Reward)).to.be.closeTo(expectedUser1RewardFinal, tolerance);
            expect(BigInt(actualUser2Reward)).to.be.closeTo(expectedUser2Reward, tolerance);

            // Verify balances after claim
            await tokenLock.claim();
            await tokenLock.connect(user2).claim();

            await expect(await tokenLock.currentUserRewards(user1.address)).to.equal(0);

            const ownerBalance = await treasuryToken.balanceOf(user1.address);
            const user1Balance = await treasuryToken.balanceOf(user2.address);

            expect(BigInt(ownerBalance)).to.equal(actualUser1Reward);
            expect(BigInt(user1Balance)).to.equal(actualUser2Reward);

            // Unstake tokens
            await tokenLock.unstake(tokenId);
            await expect(await mockContract.tokenOwner(tokenId)).to.equal(owner.address);

            await tokenLock.connect(user2).unstake(user2TokenId);
            await expect(await mockContract.tokenOwner(user2TokenId)).to.equal(user2.address);
        });
    });
});
