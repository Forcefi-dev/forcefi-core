const { expect } = require("chai");

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

            forcefiPackageAddress = '0x358AA13c52544ECCEF6B0ADD0f801012ADAD5eE3';
            await expect(forcefiBaseContract.connect(addr1).setForcefiPackageAddress(forcefiPackageAddress)).to.be.revertedWithCustomError(forcefiBaseContract, `OwnableUnauthorizedAccount`);
            await forcefiBaseContract.setForcefiPackageAddress(forcefiPackageAddress);
            const updatedForcefiPackageAddress = await forcefiBaseContract.forcefiPackageAddress();
            expect(updatedForcefiPackageAddress).to.equal(forcefiPackageAddress);

        });
    });
});
