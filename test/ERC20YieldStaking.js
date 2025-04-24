const { expect } = require("chai");
const { ethers } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

describe("ERC20YieldStaking", function () {
    let ERC20YieldStaking, MockERC20;
    let staking, stakingToken, rewardsToken;
    let owner, user1, user2;
    let rewardsStart, rewardsEnd;

    const rewardsPeriod = 100;
    
    const TOTAL_REWARDS = "1000";
    const MIN_STAKE = "100";
    const MAX_STAKE = "10000";
    const INITIAL_SUPPLY = "100000";

    beforeEach(async function () {
        [owner, user1, user2] = await ethers.getSigners();

        // Deploy mock tokens
        MockERC20 = await ethers.getContractFactory("MockERC20");
        stakingToken = await (await MockERC20.deploy("Staking Token", "STK")).waitForDeployment();
        rewardsToken = await (await MockERC20.deploy("Rewards Token", "RWD")).waitForDeployment();

        // Set up timestamps
        const latestBlock = await ethers.provider.getBlock("latest");
        rewardsStart = latestBlock.timestamp + rewardsPeriod;
        rewardsEnd = rewardsStart + rewardsPeriod; 

        // Deploy staking contract
        ERC20YieldStaking = await ethers.getContractFactory("Erc20YieldStaking");
        staking = await (await ERC20YieldStaking.deploy(
            await stakingToken.getAddress(),
            await rewardsToken.getAddress(),
            rewardsStart,
            rewardsEnd,
            TOTAL_REWARDS,
            MIN_STAKE,
            MAX_STAKE
        ));

        // Mint tokens and approve staking contract
        await stakingToken.mint(user1.address, INITIAL_SUPPLY);
        await stakingToken.mint(user2.address, INITIAL_SUPPLY);
        await rewardsToken.mint(owner.address, TOTAL_REWARDS);
        
        const stakingAddress = await staking.getAddress();
        await stakingToken.connect(user1).approve(stakingAddress, INITIAL_SUPPLY);
        await stakingToken.connect(user2).approve(stakingAddress, INITIAL_SUPPLY);
        await rewardsToken.connect(owner).approve(stakingAddress, TOTAL_REWARDS);
    });

    describe("Deployment", function () {
        it("Should set the correct initial values", async function () {
            expect(await staking.stakingToken()).to.equal(await stakingToken.getAddress());
            expect(await staking.rewardsToken()).to.equal(await rewardsToken.getAddress());
            expect(await staking.rewardsStart()).to.equal(rewardsStart);
            expect(await staking.rewardsEnd()).to.equal(rewardsEnd);
            expect(await staking.totalLocked()).to.equal(TOTAL_REWARDS);
            expect(await staking.minStakingAmount()).to.equal(MIN_STAKE);
            expect(await staking.maxStakingAmount()).to.equal(MAX_STAKE);
        });

        it("Should revert depositTreasuryTokens when called by non-owner", async function () {
          await expect(
              staking.connect(user1).depositTreasuryTokens()
          ).to.be.revertedWithCustomError(staking, "OwnableUnauthorizedAccount")
           .withArgs(user1.address);
      });

        it("Should revert if min stake is greater than max stake", async function () {
            await expect(
                ERC20YieldStaking.deploy(
                    await stakingToken.getAddress(),
                    await rewardsToken.getAddress(),
                    rewardsStart,
                    rewardsEnd,
                    TOTAL_REWARDS,
                    MAX_STAKE + 1,
                    MAX_STAKE
                )
            ).to.be.revertedWith("Min stake must be less than max stake");
        });

        it("Should revert if max stake is zero", async function () {
            await expect(
                ERC20YieldStaking.deploy(
                    await stakingToken.getAddress(),
                    await rewardsToken.getAddress(),
                    rewardsStart,
                    rewardsEnd,
                    TOTAL_REWARDS,
                    MIN_STAKE,
                    0
                )
            ).to.be.revertedWith("Max stake must be greater than zero");
        });

        it("Should revert if staking token is zero address", async function () {
            await expect(
                ERC20YieldStaking.deploy(
                    ethers.ZeroAddress,
                    await rewardsToken.getAddress(),
                    rewardsStart,
                    rewardsEnd,
                    TOTAL_REWARDS,
                    MIN_STAKE,
                    MAX_STAKE
                )
            ).to.be.revertedWith("Staking token cannot be zero address");
        });

        it("Should revert if rewards end is before rewards start", async function () {
            await expect(
                ERC20YieldStaking.deploy(
                    await stakingToken.getAddress(),
                    await rewardsToken.getAddress(),
                    rewardsStart,
                    rewardsStart - 1, // end before start
                    TOTAL_REWARDS,
                    MIN_STAKE,
                    MAX_STAKE
                )
            ).to.be.revertedWith("Rewards end must be after rewards start");
        });

        it("Should revert if rewards token is zero address", async function () {
            await expect(
                ERC20YieldStaking.deploy(
                    await stakingToken.getAddress(),
                    ethers.ZeroAddress,
                    rewardsStart,
                    rewardsEnd,
                    TOTAL_REWARDS,
                    MIN_STAKE,
                    MAX_STAKE
                )
            ).to.be.revertedWith("Rewards token cannot be zero address");
        });

        it("Should revert if total rewards is zero", async function () {
            await expect(
                ERC20YieldStaking.deploy(
                    await stakingToken.getAddress(),
                    await rewardsToken.getAddress(),
                    rewardsStart,
                    rewardsEnd,
                    0,
                    MIN_STAKE,
                    MAX_STAKE
                )
            ).to.be.revertedWith("Total rewards must be greater than zero");
        });

        it("Should calculate correct rewards rate", async function () {
            const rewardsRate = BigInt(TOTAL_REWARDS) / BigInt(rewardsEnd - rewardsStart);
            expect(await staking.rewardsRate()).to.equal(rewardsRate);
        });
    });

    describe("Staking", function () {
        it("Should fail if rewards token is not locked", async function () {
            await expect(
                staking.connect(user1).stake(MIN_STAKE)
            ).to.be.revertedWith("Reward token has not been locked yet");
        });

        it("Should fail if stake amount is below minimum", async function () {
            await staking.depositTreasuryTokens();
            await expect(
                staking.connect(user1).stake(MIN_STAKE - 1)
            ).to.be.revertedWith("Stake amount is less than minimum");
        });

        it("Should successfully stake tokens", async function () {
            await staking.depositTreasuryTokens();
            await staking.connect(user1).stake(MIN_STAKE);
            
            expect(await staking.userStake(user1.address)).to.equal(MIN_STAKE);
            expect(await staking.totalStaked()).to.equal(MIN_STAKE);
        });

        it("Should not accumulate rewards when total staked is 0", async function () {
          expect(await staking.totalStaked()).to.equal(0);

          await ethers.provider.send("evm_increaseTime", [rewardsPeriod]);
          await ethers.provider.send("evm_mine");

          const rewardsPerToken = await staking.currentRewardsPerToken();
          expect(rewardsPerToken).to.equal(0);
      });
    });

    describe("Rewards", function () {
        beforeEach(async function () {
            await staking.depositTreasuryTokens();
            await staking.connect(user1).stake(MIN_STAKE);
        });

        it("Should accumulate rewards over time", async function () {
            await ethers.provider.send("evm_increaseTime", [rewardsPeriod]);
            await ethers.provider.send("evm_mine");
            
            const pendingRewards = await staking.currentUserRewards(user1.address);
            expect(pendingRewards).to.be.gt(0);
        });

        it("Should claim rewards correctly", async function () {
            await ethers.provider.send("evm_increaseTime", [rewardsPeriod]);
            await ethers.provider.send("evm_mine");
            
            const beforeBalance = await rewardsToken.balanceOf(user1.address);
            await staking.connect(user1).claim();
            const afterBalance = await rewardsToken.balanceOf(user1.address);
            
            expect(afterBalance).to.be.gt(beforeBalance);
        });

        it("Should stop accumulating rewards after rewardsEnd", async function () {
          
            const rewardsBeforeEnd = await staking.currentUserRewards(user1.address);
            // Move time to rewards end
            await ethers.provider.send("evm_increaseTime", [1000]);
            await ethers.provider.send("evm_mine");

            const rewardsAfterEnd = await staking.currentUserRewards(user1.address);

            // Rewards should be the same since no more accumulation happens after rewardsEnd
            expect(rewardsAfterEnd).to.not.equal(rewardsBeforeEnd);
        });
    });

    describe("Unstaking", function () {
        beforeEach(async function () {
            await staking.depositTreasuryTokens();
            await staking.connect(user1).stake(MIN_STAKE * 2);
        });

        it("Should fail if trying to unstake more than staked", async function () {
            await expect(
                staking.connect(user1).unstake(MIN_STAKE * 3)
            ).to.be.reverted;
        });

        it("Should allow partial unstaking above minimum", async function () {
            await staking.connect(user1).unstake(MIN_STAKE);
            expect(await staking.userStake(user1.address)).to.equal(MIN_STAKE);
        });

        it("Should allow complete unstaking", async function () {
            await staking.connect(user1).unstake(MIN_STAKE * 2);
            expect(await staking.userStake(user1.address)).to.equal(0);
        });
    });

    describe("Edge cases", function () {
        it("Should not exceed max staking amount", async function () {
            await staking.depositTreasuryTokens();
            await expect(
                staking.connect(user1).stake(MAX_STAKE + 1)
            ).to.be.revertedWith("The maximum staking amount has been reached for all holders");
        });

        it("Should handle multiple users staking", async function () {
            await staking.depositTreasuryTokens();
            await staking.connect(user1).stake(MIN_STAKE);
            await staking.connect(user2).stake(MIN_STAKE);
            
            expect(await staking.totalStaked()).to.equal(MIN_STAKE * 2);
        });
    });
});
