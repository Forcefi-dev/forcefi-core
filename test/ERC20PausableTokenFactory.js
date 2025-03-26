const { expect } = require("chai");
const {Contract, ContractFactory} = require('ethers');
const {deployments, ethers} = require('hardhat');

describe("ERC20 Pausable token factory", function () {

    let erc20TokenFactory;
    let owner, addr1, addr2, mockedLzAddress;
    let endpointOwner;
    let mockEndpointA;
    let EndpointV2Mock;
    let forcefiPackage;
    const srcChainId = 1;
    const contractType = 3
    const name = "Test token";
    const symbol = "TST";
    const projectName = "Test project";
    const initialSupply = 20000;

    before(async function () {
        ForcefiPackageFactory = await ethers.getContractFactory('ForcefiPackage');
        const signers = await ethers.getSigners();

        endpointOwner = signers[2];

        const EndpointV2MockArtifact = await deployments.getArtifact('EndpointV2Mock');
        EndpointV2Mock = new ContractFactory(
            EndpointV2MockArtifact.abi,
            EndpointV2MockArtifact.bytecode,
            endpointOwner
        );
    });

    beforeEach(async function () {
        [owner, addr1, addr2, mockedLzAddress] = await ethers.getSigners();
        erc20TokenFactory = await ethers.deployContract("PausableContractFactory");

        mockEndpointA = await EndpointV2Mock.deploy(srcChainId);

        forcefiPackage = await ForcefiPackageFactory.deploy(mockEndpointA.getAddress(), owner.address);

        await erc20TokenFactory.setForcefiPackageAddress(forcefiPackage.getAddress());
    });

    describe("factory constructor", function () {

        it("should check the ownership of factory contract", async function () {
            const n = await erc20TokenFactory.owner();
            expect(n).to.equal(owner.address);
        });

    });

    describe("erc20 pausable token creation", function () {

        it("should check the ownership of new erc20 token contract instance, mint some tokens, pause/unpause token transfers", async function () {

            let capturedValue
            const captureValue = (value) => {
                capturedValue = value
                return true
            }

            await expect(erc20TokenFactory.createContract(contractType, name, symbol, projectName, initialSupply))
                .to.emit(erc20TokenFactory, 'ContractCreated')
                .withArgs(captureValue, owner.address, projectName, contractType);

            let MyContract = await ethers.getContractFactory("ERC20PausableMintableToken");
            const contract = MyContract.attach(
                capturedValue
            );
            await expect(await contract.owner()).to.equal(owner.address);
            await expect(await contract.name()).to.equal(name);
            await expect(await contract.symbol()).to.equal(symbol);

            await expect(await contract.totalSupply()).to.equal(initialSupply);

            const newMintedTokens = 500;
            await contract.mint(owner.address, newMintedTokens);
            await expect(await contract.totalSupply()).to.equal(newMintedTokens + initialSupply);
            await expect(await contract.balanceOf(owner.address)).to.equal(newMintedTokens + initialSupply);

            await expect(contract.connect(addr1).mint(owner.address, newMintedTokens)).to.be.revertedWithCustomError(contract, `OwnableUnauthorizedAccount`);

            const tokensToTransfer = 250;
            await contract.pause();
            await contract.transfer(addr1.address, tokensToTransfer)
            await expect(contract.connect(addr1).transfer(addr2.address, tokensToTransfer)).to.be.revertedWith("Pausable: paused and not whitelisted");
            await contract.unpause();
            await contract.connect(addr1).transfer(addr2.address, tokensToTransfer);
            await expect(await contract.balanceOf(addr2.address)).to.equal(tokensToTransfer);
        });

        it("create pausableMintableBurnable token", async function () {

            const pausableMintableBurnableType = 2;

            let capturedValue
            const captureValue = (value) => {
                capturedValue = value
                return true
            }

            await expect(erc20TokenFactory.createContract(pausableMintableBurnableType, name, symbol, projectName, initialSupply))
                .to.emit(erc20TokenFactory, 'ContractCreated')
                .withArgs(captureValue, owner.address, projectName, pausableMintableBurnableType);

            let MyContract = await ethers.getContractFactory("ERC20PausableMintableToken");
            const contract = MyContract.attach(
                capturedValue
            );

            await expect(await contract.totalSupply()).to.equal(initialSupply);

            const newMintedTokens = 500;
            await contract.mint(owner.address, newMintedTokens);
            await expect(await contract.totalSupply()).to.equal(newMintedTokens + initialSupply);
            await expect(await contract.balanceOf(owner.address)).to.equal(newMintedTokens + initialSupply);

            await expect(contract.connect(addr1).mint(owner.address, newMintedTokens)).to.be.revertedWithCustomError(contract, `OwnableUnauthorizedAccount`);

            const tokensToTransfer = 250;
            await contract.pause();
            await contract.transfer(addr1.address, tokensToTransfer)
            await expect(contract.connect(addr1).transfer(addr2.address, tokensToTransfer)).to.be.revertedWith("Pausable: paused and not whitelisted");
            await contract.unpause();
            await contract.connect(addr1).transfer(addr2.address, tokensToTransfer);
            await expect(await contract.balanceOf(addr2.address)).to.equal(tokensToTransfer);
        });
    });
});
