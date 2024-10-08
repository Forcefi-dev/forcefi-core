const { expect } = require("chai");

describe("Forcefi Package", function () {

    let erc20Token;
    let owner, addr1, addr2;
    const name = "Test token";
    const symbol = "TST";

    const additionalTokens = "500000000000000000000000";
    let forcefiPackage;
    let dstForcefiPackage;

    const srcChainId = 1;
    const dstChainId = 2;

    beforeEach(async function () {

        const LZEndpointMock = await hre.ethers.getContractFactory("LZEndpointMock");
        const srcChainMock = await LZEndpointMock.deploy(srcChainId);
        const dstChainMock = await LZEndpointMock.deploy(dstChainId);

        const forcefiPackageC = await hre.ethers.getContractFactory("ForcefiPackage");

        forcefiPackage = await forcefiPackageC.deploy(srcChainMock.getAddress())
        dstForcefiPackage = await forcefiPackageC.deploy(dstChainMock.getAddress())

        await srcChainMock.setDestLzEndpoint(dstForcefiPackage.getAddress(), dstChainMock.getAddress());
        await dstChainMock.setDestLzEndpoint(forcefiPackage.getAddress(), srcChainMock.getAddress());

        await forcefiPackage.setTrustedRemote(dstChainId, dstForcefiPackage.getAddress());
        await dstForcefiPackage.setTrustedRemote(srcChainId, forcefiPackage.getAddress());

        const MockOracle = await ethers.getContractFactory("MockV3Aggregator");
        const mockOracle = await MockOracle.deploy(
            "18", // decimals
            "1000"// initialAnswer
        );

        [owner, addr1, addr2] = await ethers.getSigners();
        erc20Token = await ethers.deployContract("ERC20Token", [name, symbol, additionalTokens, owner.address]);
        await forcefiPackage.whitelistTokenForInvestment(erc20Token.getAddress(), mockOracle.getAddress());
    });

    describe("addPackage updatePackage", function () {

        it("should initialize packages with correct values", async function () {
            const explorerPackage = await forcefiPackage.packages(0);

            expect(explorerPackage.label).to.equal("Explorer");
            expect(explorerPackage.amount).to.equal(750);
            expect(explorerPackage.isCustom).to.equal(false);
            expect(explorerPackage.referralFee).to.equal(5);

            const acceleratorPackage = await forcefiPackage.packages(1);

            expect(acceleratorPackage.label).to.equal("Accelerator");
            expect(acceleratorPackage.amount).to.equal(2000);
            expect(acceleratorPackage.isCustom).to.equal(false);
            expect(acceleratorPackage.referralFee).to.equal(5);
        });

        it("adding new package should persist on chain", async function () {
            await forcefiPackage.addPackage("Competetor", 5000, false, 5, false);
            const competetorPackage = await forcefiPackage.packages(2);

            expect(competetorPackage.label).to.equal("Competetor");
            expect(competetorPackage.amount).to.equal(5000);
            expect(competetorPackage.isCustom).to.equal(false);
            expect(competetorPackage.referralFee).to.equal(5);
        });

        it("update package should change settings", async function () {
            await forcefiPackage.addPackage("Competetor", 5000, false, 5, false);
            await forcefiPackage.updatePackage("Competetor", 7500, true, 15);
            const competetorPackage = await forcefiPackage.packages(2);

            expect(competetorPackage.label).to.equal("Competetor");
            expect(competetorPackage.amount).to.equal(7500);
            expect(competetorPackage.isCustom).to.equal(true);
            expect(competetorPackage.referralFee).to.equal(15);
        });

    });


    describe("whitelistTokenForInvestment removeWhitelistInvestmentToken ", function () {
        it("whitelist erc 20 token", async function () {

            expect(await forcefiPackage.whitelistedToken(erc20Token.getAddress())).to.equal(true);

            // Now remove from whitelist
            await forcefiPackage.removeWhitelistInvestmentToken(erc20Token.getAddress(), erc20Token.getAddress());
            expect(await forcefiPackage.whitelistedToken(erc20Token.getAddress())).to.equal(false);
        });
    });

    describe("buyPackage", function () {
        const _projectName = "Forcefi";
        const _packageLabel = "Explorer";
        const _acceleratorPackageLabel = "Accelerator";

        it("buy Explorer package", async function () {
            const packageTotalPrice = 750;
            const erc20TokenPrice = await forcefiPackage.getChainlinkDataFeedLatestAnswer(erc20Token.getAddress());
            const totalTokensPerExplorerPackage = packageTotalPrice * Number(erc20TokenPrice);
            await erc20Token.approve(forcefiPackage.getAddress(), totalTokensPerExplorerPackage.toString());

            await forcefiPackage.buyPackage(_projectName, _packageLabel, erc20Token.getAddress(), addr1.address)

            // Try to buy package one more time should revert
            await expect(forcefiPackage.buyPackage(_projectName, _packageLabel, erc20Token.getAddress(), addr1.address)).to.be.revertedWith("Project has already bought this package");

            const expectedTokenAmount = additionalTokens - totalTokensPerExplorerPackage
            const normalizedExpectedTokenAmount = expectedTokenAmount.toLocaleString('en-US', { maximumFractionDigits: 0 }).replace(/,/g, '')

            // Check balances of contract, buyer, referral
            await expect(await erc20Token.balanceOf(owner.address)).to.equal(normalizedExpectedTokenAmount)
            const referralFee = totalTokensPerExplorerPackage * 5 / 100;
            const normalizedReferralFee = referralFee.toLocaleString('en-US', { maximumFractionDigits: 0 }).replace(/,/g, '')

            await expect(await erc20Token.balanceOf(addr1.address)).to.equal(normalizedReferralFee)

            const expectedContractRevenue = totalTokensPerExplorerPackage - referralFee
            const normalizedExpectedContractRevenue = expectedContractRevenue.toLocaleString('en-US', { maximumFractionDigits: 0 }).replace(/,/g, '')

            await expect(await erc20Token.balanceOf(forcefiPackage.getAddress())).to.equal(normalizedExpectedContractRevenue)

        });

        it("bridge Accelerator package / creation token", async function () {
            const packageTotalPrice = 2000;
            const erc20TokenPrice = await forcefiPackage.getChainlinkDataFeedLatestAnswer(erc20Token.getAddress());
            const totalTokensPerPackage = packageTotalPrice * Number(erc20TokenPrice);
            await erc20Token.approve(forcefiPackage.getAddress(), totalTokensPerPackage.toString());

            await forcefiPackage.buyPackage(_projectName, _acceleratorPackageLabel, erc20Token.getAddress(), addr1.address);
            expect(await forcefiPackage.hasCreationToken(owner, _projectName)).to.equal(true);

            // Check dst chain for creation token
            expect(await dstForcefiPackage.hasCreationToken(owner, _projectName)).to.equal(false);

            // Bridge creation token
            await forcefiPackage.bridgeToken(dstChainId, _projectName, 0);
            expect(await dstForcefiPackage.hasCreationToken(owner, _projectName)).to.equal(true);
        });

        it("buy Accelerator package after buying Explorer", async function () {
            const tokensPerExplorerPackage = 750;
            const tokensPerAcceleratorPackage = 2000;
            const erc20TokenPrice = await forcefiPackage.getChainlinkDataFeedLatestAnswer(erc20Token.getAddress());
            const totalTokensPerExplorerPackage = tokensPerExplorerPackage * Number(erc20TokenPrice);
            await erc20Token.approve(forcefiPackage.getAddress(), totalTokensPerExplorerPackage.toString());


            await forcefiPackage.buyPackage(_projectName, _packageLabel, erc20Token.getAddress(), "0x0000000000000000000000000000000000000000")

            // Approve more funds
            const totalTokensPerAcceleratorPackage = tokensPerAcceleratorPackage * Number(erc20TokenPrice);
            const normalizedTotalTokensPerAcceleratorPackage = totalTokensPerAcceleratorPackage.toLocaleString('en-US', { maximumFractionDigits: 0 }).replace(/,/g, '')

            await erc20Token.approve(forcefiPackage.getAddress(), normalizedTotalTokensPerAcceleratorPackage);

            // Check hasCreationToken before buying "Accelerator" package
            expect(await forcefiPackage.hasCreationToken(owner, _projectName)).to.equal(false);

            // buy package
            await forcefiPackage.buyPackage(_projectName, _acceleratorPackageLabel, erc20Token.getAddress(), "0x0000000000000000000000000000000000000000")

            // check balances
            const expectedBalance = additionalTokens - totalTokensPerAcceleratorPackage;
            const normalizedExpectedBalance = expectedBalance.toLocaleString('en-US', { maximumFractionDigits: 0 }).replace(/,/g, '')
            await expect(await erc20Token.balanceOf(owner.address)).to.equal(normalizedExpectedBalance)
            await expect(await erc20Token.balanceOf(forcefiPackage.getAddress())).to.equal(normalizedTotalTokensPerAcceleratorPackage)

            // Check hasCreationToken after buying "Accelerator" package, should set true
            expect(await forcefiPackage.hasCreationToken(owner, _projectName)).to.equal(true);
        });

    });

    describe("withdraw project funds", function () {
        it("withdraw project funds to another address", async function () {
            const _projectName = "Forcefi";
            const _packageLabel = "Explorer";
            const tokensPerExplorerPackage = 750;
            const erc20TokenPrice = await forcefiPackage.getChainlinkDataFeedLatestAnswer(erc20Token.getAddress());
            const totalTokensPerExplorerPackage = tokensPerExplorerPackage * Number(erc20TokenPrice);
            await erc20Token.approve(forcefiPackage.getAddress(), totalTokensPerExplorerPackage.toString());
            await forcefiPackage.buyPackage(_projectName, _packageLabel, erc20Token.getAddress(), "0x0000000000000000000000000000000000000000")

            await forcefiPackage.withdrawToken(erc20Token.getAddress(), addr1.address, totalTokensPerExplorerPackage.toString());

            await expect(await erc20Token.balanceOf(forcefiPackage.getAddress())).to.equal(0)
            await expect(await erc20Token.balanceOf(addr1.address)).to.equal(totalTokensPerExplorerPackage.toString())
        });

    });
});
