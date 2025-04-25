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
            await expect(forcefiBaseContract.connect(addr1).withdrawFee(addr1.address))
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
            await forcefiBaseContract.setForcefiPackageAddress(ethers.ZeroAddress);
            expect(await forcefiBaseContract.forcefiPackageAddress()).to.equal(ethers.ZeroAddress);
        });
    });
});
