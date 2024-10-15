const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("TokenLock", function () {
    let token, treasuryToken, tokenLock;
    let owner, user1, user2;
    const initialTreasuryBalance = 1000 // 1000 tokens
    const monthlyReleaseAmount = 1000 // 100 tokens monthly

    const vestingDuration = 30000;
    const vestingPeriod = 6000;
    const tgeAmount = 0;

    beforeEach(async function () {
        // Get signers
        [owner, user1, user2] = await ethers.getSigners();

        // Deploy mock ERC20 tokens
        const Token = await ethers.getContractFactory("ERC20Token"); // Use OpenZeppelin's ERC20 Mock
        token = await Token.deploy("Token", "TKN", 1000, owner.address);
        treasuryToken = await Token.deploy("TreasuryToken", "TREAS", 5000, owner.address);

        // Deploy TokenLock contract
        const TokenLock = await ethers.getContractFactory("TokenLock");
        tokenLock = await TokenLock.deploy(
            token.getAddress(),
            treasuryToken.getAddress(),
            initialTreasuryBalance,
            Math.floor(Date.now() / 1000),
            vestingDuration,
            vestingPeriod,
            tgeAmount,
            // 7 * 24 * 60 * 60, // beginnerFeeThreshold = 1 week
            // 10, // beginnerMultiplier = 10%
            // 30 * 24 * 60 * 60, // intermediateFeeThreshold = 1 month
            // 20, // intermediateMultiplier = 20%
            // 90 * 24 * 60 * 60, // maximumFeeThreshold = 3 months
            // 30, // maximumMultiplier = 30%

        );

        // Transfer some treasury tokens to the TokenLock contract
        await treasuryToken.approve(tokenLock.getAddress(), initialTreasuryBalance);
        await tokenLock.depositTreasuryTokens(initialTreasuryBalance);
    });

    describe("Token locking", function () {
        it("should lock tokens correctly", async function () {
            const amount = 100; // Use a regular number for the token amount

            // User1 needs some tokens first
            await token.transfer(user1.address, amount);

            // User1 approves the contract to transfer tokens
            await token.connect(user1).approve(tokenLock.getAddress(), amount); // Correct way to get the contract's address

            // User1 locks the tokens
            await tokenLock.connect(user1).lockTokens(amount);

            // Retrieve the user's first lock
            const userLocks = await tokenLock.userLocks(user1.address, 0);

            // Check that the locked amount is correct
            expect(userLocks.amount).to.equal(amount);
        });


        it("should emit Locked event on token lock", async function () {
            const amount = 100;

            await token.transfer(user1.address, amount);
            await token.connect(user1).approve(tokenLock.getAddress(), amount);

            await expect(tokenLock.connect(user1).lockTokens(amount))
                .to.emit(tokenLock, "Locked")
                .withArgs(user1.address, amount);
        });
    });

    describe("Claiming tokens", function () {
        it("should not allow claiming before lock-up period", async function () {
            const amount = 100;

            await token.transfer(user1.address, amount);
            await token.connect(user1).approve(tokenLock.getAddress(), amount);
            await tokenLock.connect(user1).lockTokens(amount);

            await expect(tokenLock.connect(user1).claim()).to.be.revertedWith("No tokens available to claim");
        });

        it("should apply beginner multiplier after 1 week", async function () {
            const amount = 100;

            await token.approve(user1.address, amount);
            await token.transfer(user1.address, amount);
            await token.connect(user1).approve(tokenLock.getAddress(), amount);
            await tokenLock.connect(user1).lockTokens(amount);

            // Add one more investor
            await token.approve(user2.address, amount);
            await token.transfer(user2.address, amount);
            await token.connect(user2).approve(tokenLock.getAddress(), amount);
            await tokenLock.connect(user2).lockTokens(amount);

            // Move forward in time by 1 week
            await ethers.provider.send("evm_increaseTime", [vestingPeriod]);
            await ethers.provider.send("evm_mine");

            console.log("========================== vestingStartTime ====================== " + await tokenLock.vestingStartTime())
            console.log("========================== vestingDuration ====================== " + await tokenLock.vestingDuration())
            console.log("========================== vestingPeriod ====================== " + await tokenLock.vestingPeriod())
            console.log("========================== lockUpPeriod ====================== " + await tokenLock.lockUpPeriod())

            console.log("========================== treasuryBalance AMOUNT====================== " + await tokenLock.treasuryBalance())
            console.log("========================== getEligibleLockedTokens AMOUNT====================== " + await tokenLock.getEligibleLockedTokens())

            console.log("========================== RELEASABLE AMOUNT====================== " + await tokenLock.getProjectReleasableAmount())
            await tokenLock.connect(user1).claim();

            // The multiplier for 1 week should be applied (beginner multiplier of 10%)
            const treasuryBalance = await treasuryToken.balanceOf(user1.address);

            const one_vesting_period_amount = initialTreasuryBalance / (vestingDuration / vestingPeriod)
            // Since there's only one investor he gets all releasable tokens
            // expect(treasuryBalance).to.equal(one_vesting_period_amount);
            // expect(await treasuryToken.balanceOf(user1.address)).to.equal(one_vesting_period_amount / 2);


            // await expect(tokenLock.connect(user2).claim()).to.be.revertedWith("No tokens available to claim");
            //
            // // Pass one more period
            // await ethers.provider.send("evm_increaseTime", [vestingPeriod]);
            // await ethers.provider.send("evm_mine");
            //
            // console.log("========================== RELEASABLE AMOUNT====================== " + await tokenLock.getProjectReleasableAmount())
            //
            // await tokenLock.connect(user1).claim();
            // await tokenLock.connect(user2).claim();
            // expect(await treasuryToken.balanceOf(user2.address)).to.equal(one_vesting_period_amount / 2);
            // expect(await treasuryToken.balanceOf(user1.address)).to.equal(one_vesting_period_amount + one_vesting_period_amount / 2);
        });
    });

    describe("Treasury management", function () {
        it("should not allow the owner to deposit into the treasury multiple times", async function () {
            const depositAmount = 500;

            await treasuryToken.approve(tokenLock.getAddress(), depositAmount);

            await expect(tokenLock.connect(owner).depositTreasuryTokens(depositAmount)).to.be.revertedWith(
                "Treasury token already locked"
            );
        });
    });

});
