const { expect } = require("chai");
const {Contract, ContractFactory} = require('ethers');
const {deployments, ethers} = require('hardhat');
const { BigNumber } = require("ethers");

describe("Forcefi Package", function () {

    let erc20Token;
    let owner, addr1, addr2;
    const name = "Test token";
    const symbol = "TST";

    const additionalTokens = BigInt("500000000000000000000000");
    let forcefiPackage;
    let dstForcefiPackage;

    const srcChainId = 1;
    const dstChainId = 2;

    let EndpointV2Mock;
    let ownerA;
    let ownerB;
    let endpointOwner;
    let mockEndpointA;
    let mockEndpointB;

    let bridgeOptions = "0x0003010011010000000000000000000000000000ea60";

    before(async function () {
        ForcefiPackageFactory = await ethers.getContractFactory('ForcefiPackage');
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

        [owner, addr1, addr2] = await ethers.getSigners();

        mockEndpointA = await EndpointV2Mock.deploy(srcChainId);
        mockEndpointB = await EndpointV2Mock.deploy(dstChainId);

        forcefiPackage = await ForcefiPackageFactory.deploy(mockEndpointA.getAddress(), ownerA.address);
        dstForcefiPackage = await ForcefiPackageFactory.deploy(mockEndpointB.getAddress(), ownerA.address);

        await mockEndpointA.setDestLzEndpoint(dstForcefiPackage.getAddress(), mockEndpointB.getAddress());
        await mockEndpointB.setDestLzEndpoint(forcefiPackage.getAddress(), mockEndpointA.getAddress());

        const srcForcefiPackageAddress = await dstForcefiPackage.getAddress();
        const dstForcefiPackageAddress = await forcefiPackage.getAddress();

        await forcefiPackage.setPeer(dstChainId, ethers.zeroPadValue(dstForcefiPackageAddress, 32));
        await dstForcefiPackage.setPeer(srcChainId, ethers.zeroPadValue(srcForcefiPackageAddress, 32));

        const MockOracle = await ethers.getContractFactory("MockV3Aggregator");
        const mockOracle = await MockOracle.deploy(
            "18", // decimals
            "1000"// initialAnswer
        );

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

            await expect(
                forcefiPackage.connect(addr1).removeWhitelistInvestmentToken(erc20Token.getAddress(), erc20Token.getAddress())
            ).to.be.revertedWithCustomError(forcefiPackage, "OwnableUnauthorizedAccount")
            .withArgs(await addr1.getAddress());
            
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
            const totalTokensPerExplorerPackage = BigInt(packageTotalPrice * Number(erc20TokenPrice));
            await erc20Token.approve(forcefiPackage.getAddress(), totalTokensPerExplorerPackage.toString());

            await forcefiPackage.buyPackage(_projectName, _packageLabel, erc20Token.getAddress(), addr1.address)

            // Try to buy package one more time should revert
            await expect(forcefiPackage.buyPackage(_projectName, _packageLabel, erc20Token.getAddress(), addr1.address)).to.be.revertedWith("Project has already bought this package");

            const expectedTokenAmount = additionalTokens - totalTokensPerExplorerPackage

            // Check balances of contract, buyer, referral
            await expect(await erc20Token.balanceOf(owner.address)).to.equal(expectedTokenAmount)
            const referralFee = totalTokensPerExplorerPackage * BigInt(5) / BigInt(100);
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
            // await forcefiPackage.bridgeToken(dstChainId, _projectName, bridgeOptions, { value: 0 });
            // expect(await dstForcefiPackage.hasCreationToken(owner, _projectName)).to.equal(true);
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
            const expectedBalance = additionalTokens - BigInt(totalTokensPerAcceleratorPackage);
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

            await expect(
                forcefiPackage.connect(addr1).withdrawToken(erc20Token.getAddress(), addr1.address, totalTokensPerExplorerPackage.toString())
            ).to.be.revertedWithCustomError(forcefiPackage, "OwnableUnauthorizedAccount")
            .withArgs(await addr1.getAddress());

            await forcefiPackage.withdrawToken(erc20Token.getAddress(), addr1.address, totalTokensPerExplorerPackage.toString());

            await expect(await erc20Token.balanceOf(forcefiPackage.getAddress())).to.equal(0)
            await expect(await erc20Token.balanceOf(addr1.address)).to.equal(totalTokensPerExplorerPackage.toString())
        });

    });

    describe("bridgeToken", function () {
        const _projectName = "Forcefi";
        
        beforeEach(async function () {
            // Buy Accelerator package to get creation token
            const packageTotalPrice = 2000;
            const erc20TokenPrice = await forcefiPackage.getChainlinkDataFeedLatestAnswer(erc20Token.getAddress());
            const totalTokensPerPackage = packageTotalPrice * Number(erc20TokenPrice);
            await erc20Token.approve(forcefiPackage.getAddress(), totalTokensPerPackage.toString());
            await forcefiPackage.buyPackage(_projectName, "Accelerator", erc20Token.getAddress(), addr1.address);
        });

        it("should fail bridging without creation token", async function () {
            await expect(
                forcefiPackage.connect(addr2).bridgeToken(dstChainId, _projectName, bridgeOptions)
            ).to.be.revertedWith("No token to bridge");
        });
    });

    describe("quote", function () {
        it("should return quote for bridging", async function () {
            const fee = await forcefiPackage.quote(dstChainId, "TestMessage", bridgeOptions, false);
            expect(fee.nativeFee).to.be.gt(0);
            expect(fee.lzTokenFee).to.equal(0);
        });
    });

    describe("package management", function () {
        it("should not allow non-owner to add package", async function () {
            await expect(
                forcefiPackage.connect(addr1).addPackage("Premium", 10000, true, 10, true)
            ).to.be.reverted;
        });

        it("should not allow updating non-existent package", async function () {
            await expect(
                forcefiPackage.updatePackage("NonExistent", 5000, true, 5)
            ).to.be.revertedWith("Package not found");
        });

        it("should validate package purchase requirements", async function () {
            await expect(
                forcefiPackage.buyPackage("Test", "Explorer", addr2.address, addr1.address)
            ).to.be.revertedWith("Not whitelisted investment token");
        });

        it("should not allow non-owner to update package", async function () {
            await forcefiPackage.addPackage("Premium", 10000, false, 10, true);
            await expect(
                forcefiPackage.connect(addr1).updatePackage("Premium", 15000, true, 15)
            ).to.be.revertedWithCustomError(forcefiPackage, "OwnableUnauthorizedAccount")
            .withArgs(await addr1.getAddress());
        });

    });

    describe("owner functions", function () {
        it("should allow owner to mint token directly", async function () {
            expect(await forcefiPackage.hasCreationToken(addr2.address, "TestProject")).to.equal(false);

            await expect(
                forcefiPackage.connect(addr1).ownerMintToken(addr2.address, "TestProject")
            ).to.be.revertedWithCustomError(forcefiPackage, "OwnableUnauthorizedAccount")
            .withArgs(await addr1.getAddress());

            await forcefiPackage.ownerMintToken(addr2.address, "TestProject");
            expect(await forcefiPackage.hasCreationToken(addr2.address, "TestProject")).to.equal(true);
        });
    });

    describe("price feed calculations", function () {
        it("should handle different token decimals correctly", async function () {
            const Token18Dec = await ethers.getContractFactory("ERC20Token");
            const token18 = await Token18Dec.deploy("Token18", "T18", "1000000000000000000000", owner.address);

            const Token6Dec = await ethers.getContractFactory("ERC20Token6Dec");
            const token6 = await Token6Dec.deploy("Token6", "T6", "1000000", owner.address);

            const MockOracle = await ethers.getContractFactory("MockV3Aggregator");
            const mockOracle18 = await MockOracle.deploy("8", "100000000"); // $1.00 with 8 decimals

            await expect(
                forcefiPackage.connect(addr1).whitelistTokenForInvestment(token18.getAddress(), mockOracle18.getAddress())
            ).to.be.revertedWithCustomError(forcefiPackage, "OwnableUnauthorizedAccount")
            .withArgs(await addr1.getAddress());

            await forcefiPackage.whitelistTokenForInvestment(token18.getAddress(), mockOracle18.getAddress());
            await forcefiPackage.whitelistTokenForInvestment(token6.getAddress(), mockOracle18.getAddress());

            const price18 = await forcefiPackage.getChainlinkDataFeedLatestAnswer(token18.getAddress());
            const price6 = await forcefiPackage.getChainlinkDataFeedLatestAnswer(token6.getAddress());

            expect(price18).to.equal(ethers.parseUnits("1", 18));
            expect(price6).to.equal(ethers.parseUnits("1", 6));
        });
    });

    describe("viewProjectPackages", function () {
        const _projectName = "TestProject";
        
        it("should return empty array for project with no packages", async function () {
            const packages = await forcefiPackage.viewProjectPackages(_projectName);
            expect(packages).to.be.an('array').that.is.empty;
        });

        it("should return single package for project", async function () {
            const packageTotalPrice = 750;
            const erc20TokenPrice = await forcefiPackage.getChainlinkDataFeedLatestAnswer(erc20Token.getAddress());
            const totalTokens = BigInt(packageTotalPrice * Number(erc20TokenPrice));
            await erc20Token.approve(forcefiPackage.getAddress(), totalTokens.toString());

            await forcefiPackage.buyPackage(_projectName, "Explorer", erc20Token.getAddress(), addr1.address);
            
            const packages = await forcefiPackage.viewProjectPackages(_projectName);
            expect(packages).to.have.lengthOf(1);
            expect(packages[0]).to.equal("Explorer");
        });

        it("should return all packages for project with multiple packages", async function () {
            // Buy Explorer package
            const explorerPrice = 750;
            const acceleratorPrice = 2000;
            const erc20TokenPrice = await forcefiPackage.getChainlinkDataFeedLatestAnswer(erc20Token.getAddress());
            
            const explorerTokens = BigInt(explorerPrice * Number(erc20TokenPrice));
            await erc20Token.approve(forcefiPackage.getAddress(), explorerTokens.toString());
            await forcefiPackage.buyPackage(_projectName, "Explorer", erc20Token.getAddress(), addr1.address);

            // Buy Accelerator package
            const acceleratorTokens = BigInt(acceleratorPrice * Number(erc20TokenPrice));
            await erc20Token.approve(forcefiPackage.getAddress(), acceleratorTokens.toString());
            await forcefiPackage.buyPackage(_projectName, "Accelerator", erc20Token.getAddress(), addr1.address);

            const packages = await forcefiPackage.viewProjectPackages(_projectName);
            expect(packages).to.have.lengthOf(2);
            expect(packages).to.include("Explorer");
            expect(packages).to.include("Accelerator");
        });
    });

});
