const { expect } = require("chai");

describe("ERC20 Pausable token factory", function () {

    let erc20Token;
    let owner, addr1, addr2, addr3, mockedLzAddress;
    const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000'

    const name = "Test token";
    const symbol = "TST";
    const projectName = "Test project";
    const initialSupply = 20000;

    beforeEach(async function () {
        [owner, addr1, addr2, addr3, mockedLzAddress] = await ethers.getSigners();
        erc20Token = await ethers.deployContract("ERC20PausableToken", [name, symbol, initialSupply, owner.address]);

    });

    describe("factory constructor", function () {

        it("should check the ownership of factory contract", async function () {
            const n = await erc20Token.owner();
            expect(n).to.equal(owner.address);
        });

    });

    describe("erc20 pausable token creation", function () {


        it("should revert when trying to transfer with insufficient balance", async function () {
            await expect(erc20Token.connect(addr1).transfer(addr2.address, 1000)).to.be.revertedWithCustomError(erc20Token, "ERC20InsufficientBalance");
        });

        it("should revert when trying to approve with invalid approver", async function () {
            await expect(erc20Token.connect(addr1).approve(ZERO_ADDRESS, 500)).to.be.revertedWithCustomError(erc20Token, "ERC20InvalidSpender");
        });

        it("should revert when trying to pause by non-owner", async function () {
            await expect(erc20Token.connect(addr1).pause()).to.be.revertedWithCustomError(erc20Token, "OwnableUnauthorizedAccount");
        });

        it("should emit Approval event when approve is called", async function () {
            await expect(erc20Token.approve(addr1.address, 500))
                .to.emit(erc20Token, "Approval")
                .withArgs(owner.address, addr1.address, 500);
        });

        it("should add and remove whitelisted contract", async function () {
            await erc20Token.addWhitelistedContract(addr1.address);
            await erc20Token.addWhitelistedContract(addr1.address); // remove
        });

        it("test erc20 pausable token", async function () {

            const tokensToTransfer = 250;
            await erc20Token.pause();
            await erc20Token.transfer(addr1.address, tokensToTransfer)
            await expect(erc20Token.connect(addr1).transfer(addr2.address, tokensToTransfer)).to.be.revertedWith("Pausable: paused and not whitelisted");
            await erc20Token.unpause();
            await erc20Token.connect(addr1).transfer(addr2.address, tokensToTransfer);
            await expect(await erc20Token.balanceOf(addr2.address)).to.equal(tokensToTransfer);

            // Add whitelisted addresses
            await erc20Token.addWhitelistedContract(addr2.address);

            // Add addr1 to the whitelist
            await erc20Token.addWhitelistedContract(addr1.address);
            await expect(erc20Token.connect(addr2).addWhitelistedContract(addr1.address)).to.be.revertedWithCustomError(erc20Token, "OwnableUnauthorizedAccount");

            // Pause the contract
            await erc20Token.pause();

            // Transfer from whitelisted address
            await expect(erc20Token.transfer(addr1.address, tokensToTransfer))
                .to.emit(erc20Token, "Transfer")
                .withArgs(owner.address, addr1.address, tokensToTransfer);

            await expect(await erc20Token.balanceOf(addr1.address)).to.equal(tokensToTransfer);

            // Remove from whitelist by toggling the value again
            await erc20Token.addWhitelistedContract(addr2.address);

            await erc20Token.addWhitelistedContract(addr2.address);
            const tokensForAddr3 = tokensToTransfer / 2;
            await erc20Token.connect(addr2).transfer(addr3.address, tokensForAddr3);
            await expect(await erc20Token.balanceOf(addr3.address)).to.equal(tokensForAddr3);

            await erc20Token.unpause();
            await expect(erc20Token.connect(addr2).unpause()).to.be.revertedWithCustomError(erc20Token, "OwnableUnauthorizedAccount");
            await erc20Token.connect(addr2).transfer(addr3.address, tokensForAddr3);
            await expect(await erc20Token.balanceOf(addr3.address)).to.equal(tokensToTransfer);
        });
    });
});
