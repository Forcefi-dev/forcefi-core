const { expect } = require("chai");
const { BigNumber } = require("@ethersproject/bignumber");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");

describe("ERC20Token", function () {

    let ERC20Token, erc20TokenFactory;
    let owner, addr1, addr2, mockedLzAddress;
    const contractType = 3
    const name = "Test token";
    const symbol = "TST";
    const decimals = 18;
    const projectName = "Test project";
    const initialSupply = 20000;
    const initialSupply2 = 50000;

    beforeEach(async function () {
        [owner, addr1, addr2, mockedLzAddress] = await ethers.getSigners();
        erc20TokenFactory = await ethers.deployContract("PausableContractFactory");

        const forcefiPackage = await ethers.deployContract("ForcefiPackage", [mockedLzAddress]);
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
                .withArgs(captureValue, owner.address, projectName);

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
    });
});
