const { expect } = require("chai");

describe("ERC20Token", function () {

    let ERC20Token, erc20Token;
    let owner, addr1, addr2;
    const name = "Test token";
    const symbol = "TST";
    const initialSupply = 20000;
    const initialSupply2 = 50000;
    const lzAddress = "0x0000000000000000000000000000000000000123"

    const vestingPlans = [
        {label: "vesting_plan_1",
            saleStart: 1,
            cliffPeriod: 2,
            vestingPeriod: 3,
            releasePeriod: 4,
            tgePercent: 5,
            totalTokenAmount: initialSupply,
            tokenAllocated: 0,
            initialized: true
        },
        {label: "vesting_plan_2",
            saleStart: 1,
            cliffPeriod: 2,
            vestingPeriod: 3,
            releasePeriod: 4,
            tgePercent: 5,
            totalTokenAmount: initialSupply2,
            tokenAllocated: 0,
            initialized: true
        }
    ];
    const additionalTokens = "500000000000000000000000";
    let forcefiPackage;

    beforeEach(async function () {
        // ERC20Token = await ethers.getContractFactory("ERC20Token");
        forcefiPackage = await ethers.deployContract("ForcefiPackage", [lzAddress]);
        [owner, addr1, addr2] = await ethers.getSigners();
        erc20Token = await ethers.deployContract("ERC20Token", [name, symbol, additionalTokens]);
        await forcefiPackage.whitelistTokenForInvestment(erc20Token.getAddress(), erc20Token.getAddress());
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
