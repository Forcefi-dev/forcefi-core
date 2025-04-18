const { expect } = require("chai");
const {Contract, ContractFactory} = require('ethers');
const {deployments, ethers} = require('hardhat');

describe("ERC20 token factory", function () {

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
    const decimals = 18;
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
        erc20TokenFactory = await ethers.deployContract("ContractFactory");
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

    describe("erc20 token creation", function () {

        it("should check the ownership of new erc20 token contract instance", async function () {

            let capturedValue
            const captureValue = (value) => {
                capturedValue = value
                return true
            }

            await expect(erc20TokenFactory.createContract(contractType, name, symbol, projectName, initialSupply))
                .to.emit(erc20TokenFactory, 'ContractCreated')
                .withArgs(captureValue, owner.address, projectName, contractType);

            const MyContract = await ethers.getContractFactory("ERC20MintableBurnableToken");
            const contract = MyContract.attach(
                capturedValue
            );
            await expect(await contract.owner()).to.equal(owner.address);
            await expect(await contract.decimals()).to.equal(decimals);
            await expect(await contract.name()).to.equal(name);
            await expect(await contract.symbol()).to.equal(symbol);

            await expect(await contract.totalSupply()).to.equal(initialSupply);

            const newMintedTokens = 500;
            await contract.mint(owner.address, newMintedTokens);
            await expect(await contract.totalSupply()).to.equal(newMintedTokens + initialSupply);
            await expect(await contract.balanceOf(owner.address)).to.equal(newMintedTokens + initialSupply);

            await expect(contract.connect(addr1).mint(owner.address, newMintedTokens)).to.be.revertedWithCustomError(contract, `OwnableUnauthorizedAccount`);

            const burnableTokens = 250;
            await contract.burn(burnableTokens);
            await expect(await contract.totalSupply()).to.equal(newMintedTokens + initialSupply - burnableTokens);
            await expect(await contract.balanceOf(owner.address)).to.equal(newMintedTokens + initialSupply - burnableTokens);

            await expect(contract.connect(addr1).burn(burnableTokens)).to.be.revertedWithCustomError(contract, `ERC20InsufficientBalance`);


        });

        it("create mintable token ", async function () {

            const mintableContractType = 1;
            let capturedValue
            const captureValue = (value) => {
                capturedValue = value
                return true
            }

            await expect(erc20TokenFactory.createContract(mintableContractType, name, symbol, projectName, initialSupply))
                .to.emit(erc20TokenFactory, 'ContractCreated')
                .withArgs(captureValue, owner.address, projectName, mintableContractType);

            const MyContract = await ethers.getContractFactory("ERC20MintableToken");
            const contract = MyContract.attach(
                capturedValue
            );

            await expect(await contract.totalSupply()).to.equal(initialSupply);

            const newMintedTokens = 500;
            await contract.mint(owner.address, newMintedTokens);
            await expect(await contract.totalSupply()).to.equal(newMintedTokens + initialSupply);
            await expect(await contract.balanceOf(owner.address)).to.equal(newMintedTokens + initialSupply);

        });
    });
});
