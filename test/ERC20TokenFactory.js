const { expect } = require("chai");

describe("ERC20 token factory", function () {

    let erc20TokenFactory;
    let owner, addr1, addr2, mockedLzAddress;
    const contractType = 3
    const name = "Test token";
    const symbol = "TST";
    const decimals = 18;
    const projectName = "Test project";
    const initialSupply = 20000;

    beforeEach(async function () {
        [owner, addr1, addr2, mockedLzAddress] = await ethers.getSigners();
        erc20TokenFactory = await ethers.deployContract("ContractFactory");
        const forcefiPackage = await ethers.deployContract("ForcefiPackage", [mockedLzAddress]);
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
                .withArgs(captureValue, owner.address, projectName);

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
                .withArgs(captureValue, owner.address, projectName);

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
