const { expect } = require('chai');
const { Contract, ContractFactory } = require('ethers');
const { deployments, ethers } = require('hardhat');
const { Options } = require('@layerzerolabs/lz-v2-utilities');

describe('MyOFT Test', function () {
    const eidA = 1;
    const eidB = 2;

    let MyOFT;
    let EndpointV2Mock;
    let ownerA;
    let ownerB;
    let endpointOwner;
    let myOFTA;
    let myOFTB;
    let mockEndpointA;
    let mockEndpointB;

    before(async function () {
        MyOFT = await ethers.getContractFactory('ForcefiPackage');
        const signers = await ethers.getSigners();

        ownerA = signers[0];
        ownerB = signers[1];
        endpointOwner = signers[2];

        const EndpointV2MockArtifact = await deployments.getArtifact('EndpointV2Mock');
        EndpointV2Mock = new ContractFactory(
            EndpointV2MockArtifact.abi,
            EndpointV2MockArtifact.bytecode,
            endpointOwner
        );
    });

    beforeEach(async function () {
        mockEndpointA = await EndpointV2Mock.deploy(eidA);
        mockEndpointB = await EndpointV2Mock.deploy(eidB);

        myOFTA = await MyOFT.deploy(mockEndpointA.getAddress(), ownerA.address);
        myOFTB = await MyOFT.connect(ownerB).deploy(mockEndpointB.getAddress(), ownerB.address);

        await mockEndpointA.setDestLzEndpoint(myOFTB.getAddress(), mockEndpointB.getAddress());
        await mockEndpointB.setDestLzEndpoint(myOFTA.getAddress(), mockEndpointA.getAddress());

        // await myOFTA.connect(ownerA).setPeer(eidB, ethers.utils.zeroPad(myOFTB.getAddress(), 32));
        // await myOFTB.connect(ownerB).setPeer(eidA, ethers.utils.zeroPad(myOFTA.getAddress(), 32));
    });

    it("should initialize packages with correct values", async function () {
            const explorerPackage = await myOFTA.packages(0);

            expect(explorerPackage.label).to.equal("Explorer");
            expect(explorerPackage.amount).to.equal(750);
            expect(explorerPackage.isCustom).to.equal(false);
            expect(explorerPackage.referralFee).to.equal(5);

            const acceleratorPackage = await myOFTA.packages(1);

            expect(acceleratorPackage.label).to.equal("Accelerator");
            expect(acceleratorPackage.amount).to.equal(2000);
            expect(acceleratorPackage.isCustom).to.equal(false);
            expect(acceleratorPackage.referralFee).to.equal(5);
        });
});
