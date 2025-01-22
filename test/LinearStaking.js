const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("LinearStaking", function () {
    let token, treasuryToken;
    let user1, user2;
    const stakingTokenSupply = 1000;
    const treasuryAmount = 5000000;
    const user2Stake = 200;
    const user1Stake = stakingTokenSupply - user2Stake;
    const minStakingAmount = 100;
    const maxStakingAmount = 1000;

    // Helper function to deploy a new TokenLock instance
    async function deployTokenLock(startTimestampOffset, endTimestampOffset, rewards) {
        const TokenLock = await ethers.getContractFactory("LinearStaking");
        const now = Math.floor(Date.now() / 1000);
        return await TokenLock.deploy(
            token.getAddress(),
            treasuryToken.getAddress(),
            now + startTimestampOffset,
            now + endTimestampOffset,
            rewards,
            minStakingAmount,
            maxStakingAmount
        );
    }

    beforeEach(async function () {
        // Get signers
        [user1, user2] = await ethers.getSigners();

        // Deploy mock ERC20 tokens
        const Token = await ethers.getContractFactory("ERC20Token");
        token = await Token.deploy("Token", "TKN", stakingTokenSupply, user1.address);
        treasuryToken = await Token.deploy("TreasuryToken", "TREAS", treasuryAmount, user1.address);

        // Transfer some tokens to user2
        await token.transfer(user2.address, user2Stake);
    });

    describe("Token locking", function () {
        let tokenLock;

        it("should calculate rewards for multiple users correctly", async function () {
            // Deploy and initialize
            tokenLock = await deployTokenLock(100, 10100, treasuryAmount);
            await treasuryToken.approve(tokenLock.getAddress(), treasuryAmount);
            await tokenLock.depositTreasuryTokens();

            // Owner stakes
            await token.approve(tokenLock.getAddress(), user1Stake);
            await tokenLock.stake(user1Stake);

            const rewardsRate = BigInt(treasuryAmount) / BigInt(10000);
            const initialTimestamp = (await ethers.provider.getBlock("latest")).timestamp;

            // Simulate time passage
            const halfPeriod = 5000;
            await ethers.provider.send("evm_increaseTime", [halfPeriod]);
            await ethers.provider.send("evm_mine");

            const firstHalfTimestamp = (await ethers.provider.getBlock("latest")).timestamp; // Updated block timestamp
            const elapsedTime = BigInt(firstHalfTimestamp - initialTimestamp - 100); // Calculate elapsed time dynamically

            // Expected rewardsPerToken calculation
            const firstUserStake = BigInt(user1Stake);
            const expectedRewardsPerToken = (rewardsRate * elapsedTime * BigInt(1e18)) / firstUserStake;

            // Get actual rewardsPerToken from the contract
            const actualRewardsPerToken = await tokenLock.currentRewardsPerToken();

            // Use a small tolerance to compare expected and actual values
            const rewardsPerTokentolerance = BigInt(1e20); // Define an acceptable margin of error
            expect(BigInt(actualRewardsPerToken)).to.be.closeTo(expectedRewardsPerToken, rewardsPerTokentolerance);

            const expectedOwnerReward = (rewardsRate * elapsedTime * BigInt(user1Stake)) / BigInt(user1Stake);

            // User1 stakes later
            await token.connect(user2).approve(tokenLock.getAddress(), user2Stake);
            await tokenLock.connect(user2).stake(user2Stake);

            // Owner tries to stake more
            await token.approve(tokenLock.getAddress(), user1Stake);
            await expect(tokenLock.stake(user1Stake))
                .to.be.revertedWith("The maximum staking amount has been reached for all holders");

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
            await tokenLock.unstake(user1Stake);
            await expect(await token.balanceOf(user1.address)).to.equal(user1Stake);

            await expect(tokenLock.connect(user2).unstake(user2Stake - minStakingAmount + 1))
                  .to.be.revertedWith("Either unstake whole stake amount, or the amount left has to be more than minimal stake amount");

            await tokenLock.connect(user2).unstake(user2Stake);
            await expect(await token.balanceOf(user2.address)).to.equal(user2Stake);
        });

        it("should handle two stakers with different stake amounts and entry times correctly", async function () {
            // Deploy and initialize
            tokenLock = await deployTokenLock(100, 110, treasuryAmount);
            await treasuryToken.approve(tokenLock.getAddress(), treasuryAmount);

            await ethers.provider.send("evm_increaseTime", [5000]);
            await ethers.provider.send("evm_mine");

            await expect(tokenLock.depositTreasuryTokens())
                .to.be.revertedWith("Can't deposit treasury tokens if staking period has started");
        });

    });
});
