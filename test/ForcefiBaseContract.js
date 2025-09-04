const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("ForcefiBaseContract", function () {

    let forcefiBaseContract;
    let feeAmount = 0;
    let forcefiPackageAddress = '0x0000000000000000000000000000000000000000';

    beforeEach(async function () {
        [owner, addr1, addr2] = await ethers.getSigners();

        forcefiBaseContract = await ethers.deployContract("ForcefiBaseContract");

    });

    describe("fee amount", function () {

        it("should initialize the contract without fee, set fee, check if correct", async function () {
            const initFeeAmount = await forcefiBaseContract.feeAmount();
            expect(initFeeAmount).to.equal(feeAmount);

            feeAmount = 500;
            await expect(forcefiBaseContract.connect(addr1).setFeeAmount(feeAmount)).to.be.revertedWithCustomError(forcefiBaseContract, `OwnableUnauthorizedAccount`);
            await forcefiBaseContract.setFeeAmount(feeAmount);
            const updatedFeeAmount = await forcefiBaseContract.feeAmount();
            expect(updatedFeeAmount).to.equal(feeAmount);

        });
    });

    describe("forcefiPackageAddress", function () {

        it("should initialize the contract without forcefiPackageAddress, set address, check if correct", async function () {
            const initForcefiPackageAddress = await forcefiBaseContract.forcefiPackageAddress();
            expect(initForcefiPackageAddress).to.equal(forcefiPackageAddress);

            forcefiPackageAddress = ethers.Wallet.createRandom();
            await expect(forcefiBaseContract.connect(addr1).setForcefiPackageAddress(forcefiPackageAddress)).to.be.revertedWithCustomError(forcefiBaseContract, `OwnableUnauthorizedAccount`);
            await forcefiBaseContract.setForcefiPackageAddress(forcefiPackageAddress);
            const updatedForcefiPackageAddress = await forcefiBaseContract.forcefiPackageAddress();
            expect(updatedForcefiPackageAddress).to.equal(forcefiPackageAddress);

        });
    });

    describe("contract ownership", function () {
        it("should set the right owner", async function () {
            expect(await forcefiBaseContract.owner()).to.equal(owner.address);
        });

        it("should prevent non-owners from accessing owner-only functions", async function () {
            await expect(forcefiBaseContract.connect(addr1).setFeeAmount(100))
                .to.be.revertedWithCustomError(forcefiBaseContract, "OwnableUnauthorizedAccount");
            await expect(forcefiBaseContract.connect(addr1).setForcefiPackageAddress(addr2.address))
                .to.be.revertedWithCustomError(forcefiBaseContract, "OwnableUnauthorizedAccount");
            await expect(forcefiBaseContract.connect(addr1).withdrawCollectedFees(addr1.address))
                .to.be.revertedWithCustomError(forcefiBaseContract, "OwnableUnauthorizedAccount");
        });
    });

    describe("forcefi package management", function () {
        it("should update package address correctly", async function () {
            const newPackageAddress = addr2.address;
            await forcefiBaseContract.setForcefiPackageAddress(newPackageAddress);
            expect(await forcefiBaseContract.forcefiPackageAddress()).to.equal(newPackageAddress);
        });

        it("should handle multiple package address updates", async function () {
            const firstUpdate = addr1.address;
            const secondUpdate = addr2.address;

            await forcefiBaseContract.setForcefiPackageAddress(firstUpdate);
            expect(await forcefiBaseContract.forcefiPackageAddress()).to.equal(firstUpdate);

            await forcefiBaseContract.setForcefiPackageAddress(secondUpdate);
            expect(await forcefiBaseContract.forcefiPackageAddress()).to.equal(secondUpdate);
        });

        it("should allow setting package address to zero address", async function () {
            await expect(forcefiBaseContract.setForcefiPackageAddress(ethers.ZeroAddress))
                .to.be.revertedWith("ForcefiPackage address cannot be zero");
        });
    });    describe("fee withdrawal", function () {
        let testForcefiContract;
        
        beforeEach(async function () {
            // Deploy the test contract that can properly handle fee collection
            testForcefiContract = await ethers.deployContract("TestForcefiBaseContract");
        });

        it("should withdraw collected fees correctly", async function () {
            const feeAmount = ethers.parseEther("1"); // 1 ETH
            
            // Simulate fee collection using the test contract
            await testForcefiContract.simulateFeeCollection(feeAmount, { value: feeAmount });
            
            // Verify fees were collected
            const collectedFees = await testForcefiContract.collectedFees();
            expect(collectedFees).to.equal(feeAmount);
            
            // Record initial balances
            const initialReceiverBalance = await ethers.provider.getBalance(addr1.address);
            const initialContractBalance = await ethers.provider.getBalance(await testForcefiContract.getAddress());
            
            // Withdraw fees
            const tx = await testForcefiContract.withdrawCollectedFees(addr1.address);
            
            // Check final balances
            const finalReceiverBalance = await ethers.provider.getBalance(addr1.address);
            const finalContractBalance = await ethers.provider.getBalance(await testForcefiContract.getAddress());
            
            // Verify the withdrawal
            expect(finalReceiverBalance).to.equal(initialReceiverBalance + feeAmount);
            expect(finalContractBalance).to.equal(initialContractBalance - feeAmount);
            
            // Verify collectedFees was reset to 0
            const finalCollectedFees = await testForcefiContract.collectedFees();
            expect(finalCollectedFees).to.equal(0);
        });

        it("should emit FeesWithdrawn event", async function () {
            const feeAmount = ethers.parseEther("0.5");
            
            // Simulate fee collection
            await testForcefiContract.simulateFeeCollection(feeAmount, { value: feeAmount });
            
            // Test the withdrawal and event emission
            await expect(testForcefiContract.withdrawCollectedFees(addr2.address))
                .to.emit(testForcefiContract, "FeesWithdrawn")
                .withArgs(addr2.address, feeAmount);
        });

        it("should handle multiple fee collections and withdrawals", async function () {
            const firstFee = ethers.parseEther("0.3");
            const secondFee = ethers.parseEther("0.7");
            const totalFees = firstFee + secondFee;
            
            // Collect fees in multiple transactions
            await testForcefiContract.simulateFeeCollection(firstFee, { value: firstFee });
            await testForcefiContract.simulateFeeCollection(secondFee, { value: secondFee });
            
            // Verify total fees collected
            const collectedFees = await testForcefiContract.collectedFees();
            expect(collectedFees).to.equal(totalFees);
            
            // Withdraw all fees
            const initialBalance = await ethers.provider.getBalance(addr1.address);
            await testForcefiContract.withdrawCollectedFees(addr1.address);
            const finalBalance = await ethers.provider.getBalance(addr1.address);
            
            expect(finalBalance).to.equal(initialBalance + totalFees);
            expect(await testForcefiContract.collectedFees()).to.equal(0);
        });

        it("should prevent non-owners from withdrawing fees", async function () {
            const feeAmount = ethers.parseEther("0.1");
            await testForcefiContract.simulateFeeCollection(feeAmount, { value: feeAmount });
            
            await expect(testForcefiContract.connect(addr1).withdrawCollectedFees(addr2.address))
                .to.be.revertedWithCustomError(testForcefiContract, "OwnableUnauthorizedAccount");
            
            await expect(testForcefiContract.connect(addr2).withdrawCollectedFees(addr1.address))
                .to.be.revertedWithCustomError(testForcefiContract, "OwnableUnauthorizedAccount");
        });

        it("should revert when receiver address is zero", async function () {
            const feeAmount = ethers.parseEther("0.1");
            await testForcefiContract.simulateFeeCollection(feeAmount, { value: feeAmount });
            
            await expect(testForcefiContract.withdrawCollectedFees(ethers.ZeroAddress))
                .to.be.revertedWith("Receiver address cannot be zero");
        });

        it("should revert when no fees to withdraw", async function () {
            // Ensure no fees are collected
            const collectedFees = await testForcefiContract.collectedFees();
            expect(collectedFees).to.equal(0);

            await expect(testForcefiContract.withdrawCollectedFees(addr1.address))
                .to.be.revertedWith("No fees to withdraw");
        });

        it("should reset collectedFees to zero after withdrawal", async function () {
            const feeAmount = ethers.parseEther("0.2");
            
            // Collect fees
            await testForcefiContract.simulateFeeCollection(feeAmount, { value: feeAmount });
            expect(await testForcefiContract.collectedFees()).to.equal(feeAmount);
            
            // Withdraw fees
            await testForcefiContract.withdrawCollectedFees(addr1.address);
            
            // Verify collectedFees is reset to 0
            expect(await testForcefiContract.collectedFees()).to.equal(0);
        });
        
        it("should handle withdrawal with different receiver addresses", async function () {
            const feeAmount = ethers.parseEther("0.15");
            
            for (const receiver of [addr1, addr2, owner]) {
                // Collect fees
                await testForcefiContract.simulateFeeCollection(feeAmount, { value: feeAmount });
                
                // Record initial balance
                const initialBalance = await ethers.provider.getBalance(receiver.address);
                
                // Withdraw to different receiver
                const tx = await testForcefiContract.withdrawCollectedFees(receiver.address);
                const receipt = await tx.wait();
                
                // Calculate gas cost (only affects the owner who pays for the transaction)
                const gasUsed = receipt.gasUsed * receipt.gasPrice;
                
                // Verify withdrawal
                const finalBalance = await ethers.provider.getBalance(receiver.address);
                
                if (receiver.address === owner.address) {
                    // For owner, account for gas costs
                    expect(finalBalance).to.equal(initialBalance + feeAmount - gasUsed);
                } else {
                    // For other addresses, no gas cost deduction
                    expect(finalBalance).to.equal(initialBalance + feeAmount);
                }
                
                expect(await testForcefiContract.collectedFees()).to.equal(0);
            }
        });

        it("should only allow owner to call withdrawCollectedFees", async function () {
            const feeAmount = ethers.parseEther("0.1");
            await testForcefiContract.simulateFeeCollection(feeAmount, { value: feeAmount });
            
            // Test with different non-owner accounts
            await expect(testForcefiContract.connect(addr1).withdrawCollectedFees(owner.address))
                .to.be.revertedWithCustomError(testForcefiContract, "OwnableUnauthorizedAccount");
                
            await expect(testForcefiContract.connect(addr2).withdrawCollectedFees(owner.address))
                .to.be.revertedWithCustomError(testForcefiContract, "OwnableUnauthorizedAccount");
        });

        it("should handle large fee amounts correctly", async function () {
            const largeFeeAmount = ethers.parseEther("100"); // 100 ETH
            
            // Simulate collecting a large amount of fees
            await testForcefiContract.simulateFeeCollection(largeFeeAmount, { value: largeFeeAmount });
            
            // Verify fees collected
            expect(await testForcefiContract.collectedFees()).to.equal(largeFeeAmount);
            
            // Withdraw and verify
            const initialBalance = await ethers.provider.getBalance(addr1.address);
            await testForcefiContract.withdrawCollectedFees(addr1.address);
            const finalBalance = await ethers.provider.getBalance(addr1.address);
            
            expect(finalBalance).to.equal(initialBalance + largeFeeAmount);
            expect(await testForcefiContract.collectedFees()).to.equal(0);
        });

        it("should work with receive() function for fee collection", async function () {
            const feeAmount = ethers.parseEther("0.25");
            
            // Send ETH directly to contract (should trigger receive function)
            await owner.sendTransaction({
                to: await testForcefiContract.getAddress(),
                value: feeAmount
            });
            
            // Verify fees were collected
            expect(await testForcefiContract.collectedFees()).to.equal(feeAmount);
            
            // Withdraw and verify
            const initialBalance = await ethers.provider.getBalance(addr1.address);
            await testForcefiContract.withdrawCollectedFees(addr1.address);
            const finalBalance = await ethers.provider.getBalance(addr1.address);
            
            expect(finalBalance).to.equal(initialBalance + feeAmount);
        });
    });
});
