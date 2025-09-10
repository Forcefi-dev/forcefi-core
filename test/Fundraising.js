const { expect } = require("chai");
const {Contract, ContractFactory} = require('ethers');
const {deployments, ethers} = require('hardhat');

const getCurrentTime = async () => {
    const currentBlock = await ethers.provider.getBlock("latest");
    return currentBlock.timestamp;
}

// Utility function to create a new fundraising instance
const createNewFundraising = async (
    equityFundraising,
    projectToken,
    investmentToken,
    customData = {},
    user1 = null // Make user1 optional with default null
) => {
    const currentTime = (await ethers.provider.getBlock('latest')).timestamp;
    
    // Create campaign with specific timestamps
    const campaignData = {
        _label: "simple vesting",
        _vestingStart: currentTime,
        _cliffPeriod: 0,
        _vestingPeriod: 0,
        _releasePeriod: 0,
        _tgePercent: 0,
        _totalCampaignLimit: 300,
        _rate: 100,
        _rateDelimiter: 100,
        _startDate: currentTime,
        _endDate: currentTime + 1000, // 1000 seconds duration
        _isPrivate: false,
        _campaignMinTicketLimit: 100,
        _campaignMaxTicketLimit: 300,
        ...customData
    };

    // Setup new campaign
    const _attachedERC20Address = [await investmentToken.getAddress()];
    await projectToken.approve(equityFundraising.getAddress(), campaignData._totalCampaignLimit);
    
    const tx = await equityFundraising.createFundraising(
        campaignData,
        _attachedERC20Address,
        user1 ? user1.getAddress() : ethers.ZeroAddress, // Use ZeroAddress if no user provided
        "TestCampaign",
        projectToken.getAddress(),
        [],
        false
    );

    // Get campaign ID from event
    const receipt = await tx.wait();
    const event = receipt.logs.find(x => x.fragment && x.fragment.name === 'FundraisingCreated');
    const campaignId = event.args[1];

    return {
        campaignId,
        campaignData
    };
};

describe("EquityFundraising", function () {

    let endpointOwner;
    let mockEndpointA;
    let EndpointV2Mock;
    const srcChainId = 1;

    let equityFundraising;
    let owner;
    let user1;
    let user2;
    let user3;
    let user4;
    let mockedLzAddress;
    let mainWalletAddressMock;
    let erc20Token;
    let investmentToken;
    let investmentToken2;
    let forcefiToken;
    let projectToken;
    let forcefiPackage;
    let forcefiStaking;
    let mockCuratorContract;  // Add this line

    let capturedValue;
    let privateCampaignCapturedValue;
    let treshholdedCapturedValue;
    let newFundraisingCampaign;
    const campaignLimit = 300;
    const projectName = "Tesla"
    const additionalTokens = 10000;
    const referralFee = 5;
    const oraclePrice = ethers.parseUnits("1", 18); // 1000 USD
    const oracleDecimals = 18;

    const startDateTimestamp = getCurrentTime()
    const getEndDate = async () => {
        const currentTime = await getCurrentTime();
        return  currentTime + 5000;
    };
    const endDate = getEndDate();

    const _fundraisingData = {
        _label: "simple vesting",
        _vestingStart: 0,
        _cliffPeriod: 0,
        _vestingPeriod: 0,
        _releasePeriod: 0,
        _tgePercent: 0,
        _totalCampaignLimit: campaignLimit,
        _campaignSoftCap: 250,
        _rate: 100,
        _rateDelimiter: 100,
        _startDate: startDateTimestamp,
        _endDate: endDate,
        _isPrivate: false,
        _campaignMinTicketLimit: 100,
        _campaignMaxTicketLimit: 300
    }

    const _privateCampaignFundraisingData = {
        _label: "simple vesting",
        _vestingStart: 0,
        _cliffPeriod: 0,
        _vestingPeriod: 0,
        _releasePeriod: 0,
        _tgePercent: 0,
        _totalCampaignLimit: campaignLimit,
        _campaignSoftCap: 200,
        _rate: 1,
        _rateDelimiter: 4,
        _startDate: startDateTimestamp,
        _endDate: endDate,
        _isPrivate: true,
        _campaignMinTicketLimit: 100,
        _campaignMaxTicketLimit: 200
    }

    const minStakingAmount = 100;
    const investorTreshhold = 7500;

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

        const MockOracle = await ethers.getContractFactory("MockedV3Aggregator");
        const price = oraclePrice;
        const decimals = oracleDecimals;
        const mockOracle = await MockOracle.deploy(
            decimals,
            price
        );

        [owner, user1, user2, user3, user4, mainWalletAddressMock, mockedLzAddress] = await ethers.getSigners();
        
        // Deploy Fundraising contract with required constructor parameters
        equityFundraising = await ethers.deployContract("Fundraising", [
            1000000, // tier1Threshold (will be multiplied by 1e18 in constructor)
            2500000, // tier2Threshold (will be multiplied by 1e18 in constructor)
            5,       // tier1FeePercentage
            4,       // tier2FeePercentage
            3,       // tier3FeePercentage
            70       // minCampaignThreshold
        ]);

        const symbol = "InvestmentToken";
        const name = "INVT";
        erc20Token = await ethers.deployContract("ERC20Token", [name, symbol, additionalTokens, owner.address]);
        investmentToken = await ethers.deployContract("ERC20Token", [name, symbol, additionalTokens, owner.address]);
        investmentToken2 = await ethers.deployContract("ERC20Token", [name, symbol, additionalTokens, owner.address]);
        projectToken = await ethers.deployContract("ERC20Token", [name, symbol, additionalTokens, owner.address]);

        mockEndpointA = await EndpointV2Mock.deploy(srcChainId);

        forcefiPackage = await ForcefiPackageFactory.deploy(mockEndpointA.getAddress(), owner.address);
        await equityFundraising.setForcefiPackageAddress(forcefiPackage.getAddress());

        // Add this before your tests
        const MockCuratorContract = await ethers.getContractFactory("MockCuratorContract");
        mockCuratorContract = await MockCuratorContract.deploy();
        
        // Setup staking contract, add 1 investor who will receive fees
        forcefiToken = await ethers.deployContract("ERC20Token", [name, symbol, additionalTokens, owner.address]);
        forcefiStaking = await ethers.deployContract("AccessStaking", [forcefiToken.getAddress(), equityFundraising.getAddress(), mockEndpointA.getAddress(), owner.address]);

        await forcefiStaking.setInvestorTreshholdAmount(investorTreshhold);
        await forcefiToken.approve(forcefiStaking.getAddress(), investorTreshhold);
        await forcefiStaking.stake(investorTreshhold, owner.address);
        await forcefiStaking.setMinStakingAmount(minStakingAmount);

        await forcefiToken.transfer(user1.address, minStakingAmount);
        await forcefiToken.connect(user1).approve(forcefiStaking.getAddress(), minStakingAmount);
        await forcefiStaking.connect(user1).stake(minStakingAmount, user1.address);

        await equityFundraising.setForcefiStakingAddress(forcefiStaking.getAddress())

        const _attachedERC20Address = [
            investmentToken.getAddress(),
            investmentToken2.getAddress()
        ];

        // Try to call whitelistTokenForInvestment with non-owner address
        await expect(
            equityFundraising.connect(user2).whitelistTokenForInvestment(investmentToken.getAddress(), mockOracle.getAddress())
        ).to.be.reverted;

        equityFundraising.whitelistTokenForInvestment(investmentToken.getAddress(), mockOracle.getAddress())
        equityFundraising.whitelistTokenForInvestment(investmentToken2.getAddress(), mockOracle.getAddress())

        await equityFundraising.setReferralFee(referralFee);

        const captureValue = (value) => {
            capturedValue = value
            return true
        }

        await projectToken.approve(equityFundraising.getAddress(), campaignLimit)

        await expect(equityFundraising.createFundraising(_fundraisingData, _attachedERC20Address, user1.getAddress(), projectName, projectToken.getAddress(), [], false))
            .to.emit(equityFundraising, 'FundraisingCreated')
            .withArgs(await owner.getAddress(), (arg) => captureValue(arg) && true, projectName);


        const privateCampaignCaptureValue = (value) => {
            privateCampaignCapturedValue = value
            return true
        }

        await projectToken.approve(equityFundraising.getAddress(), campaignLimit)

        const ethDataFeed = await ethers.deployContract("MockedV3Aggregator", [
                18, // 8 decimals
                100000000 // $1.00 with 8 decimals
            ]);           

        await equityFundraising.whitelistNativeCurrencyForInvestment(ethDataFeed.getAddress());

        await expect(equityFundraising.createFundraising(_privateCampaignFundraisingData, _attachedERC20Address, user1.getAddress(), projectName, projectToken.getAddress(), [], true))
            .to.emit(equityFundraising, 'FundraisingCreated')
            .withArgs(await owner.getAddress(), (arg) => privateCampaignCaptureValue(arg) && true, projectName);

        const fundraisingCampaignWithAdjustedTreshholds = (value) => {
            treshholdedCapturedValue = value
            return true
        }

        await projectToken.approve(equityFundraising.getAddress(), campaignLimit)

        await expect(equityFundraising.createFundraising(_fundraisingData, _attachedERC20Address, user1.getAddress(), projectName, projectToken.getAddress(), [], false))
            .to.emit(equityFundraising, 'FundraisingCreated')
            .withArgs(await owner.getAddress(), (arg) => fundraisingCampaignWithAdjustedTreshholds(arg) && true, projectName);

    });

    describe("Constructor and Initial Setup", function () {
        it("Should initialize with correct default fee configuration", async function () {
            const feeConfig = await equityFundraising.feeConfig();
            expect(feeConfig.tier1Threshold).to.equal(ethers.parseUnits("1000000", 18));
            expect(feeConfig.tier2Threshold).to.equal(ethers.parseUnits("2500000", 18));
            expect(feeConfig.tier1FeePercentage).to.equal(5);
            expect(feeConfig.tier2FeePercentage).to.equal(4);
            expect(feeConfig.tier3FeePercentage).to.equal(3);
            expect(feeConfig.minCampaignThreshold).to.equal(70);
        });

        it("Should set owner correctly", async function () {
            expect(await equityFundraising.owner()).to.equal(owner.address);
        });
    });

    describe("Whitelisting and Configuration", function () {
        it("Should whitelist investment token with data feed", async function () {
            const mockOracle = await ethers.deployContract("MockedV3Aggregator", [18, 1]);
            await equityFundraising.whitelistTokenForInvestment(investmentToken.getAddress(), mockOracle.getAddress());
            expect(await equityFundraising.isInvestmentToken(investmentToken.getAddress())).to.be.true;
        });

        it("Should handle Chainlink price with different token decimals", async function () {
            // Create a mock oracle with 8 decimals (like most Chainlink feeds)
            const mockOracle = await ethers.deployContract("MockedV3Aggregator", [8, 100000000]); // $1.00 with 8 decimals
            
            // Deploy 6 decimal token (like USDC)
            const token6Dec = await ethers.deployContract("ERC20Token6Dec", ["USDC Mock", "USDC", 1000000, owner.address]);
            
            // Whitelist the 6-decimal token
            await equityFundraising.whitelistTokenForInvestment(token6Dec.getAddress(), mockOracle.getAddress());
            
            // Get price from Chainlink feed
            const price = await equityFundraising.getChainlinkDataFeedLatestAnswer(token6Dec.getAddress());
            
            // Since token has 6 decimals and feed has 8 decimals,
            // The price should be adjusted from 8 decimals to 6 decimals
            // 100000000 (8 decimals) -> 1000000 (6 decimals)
            expect(price).to.equal(1000000);
        });

        it("Should handle Chainlink price conversion with token having more decimals than feed", async function () {
            // Create mock oracle with 8 decimals (like Chainlink)
            const mockOracle = await ethers.deployContract("MockedV3Aggregator", [
                8, // 8 decimals
                100000000 // $1.00 with 8 decimals
            ]);

            // Deploy token with 20 decimals
            const token20Dec = await ethers.deployContract("ERC20Token20Dec", [
                "TwentyDec", 
                "TWD", 
                1000000, 
                owner.address
            ]);

            // Whitelist the 20-decimal token
            await equityFundraising.whitelistTokenForInvestment(token20Dec.getAddress(), mockOracle.getAddress());

            // Get price from Chainlink feed
            const price = await equityFundraising.getChainlinkDataFeedLatestAnswer(token20Dec.getAddress());

            // Since token has 20 decimals and feed has 8 decimals,
            // the price should be multiplied by 10^(20-8) = 10^12
            // 100000000 * 10^12 = 100000000000000000000
            expect(price).to.equal(ethers.parseUnits("100", 18)); // 100 with 18 zeros
        });

        it("Should set referral fee", async function () {
            const newFee = 10;

            // Try to call with invalid owner address
            await expect(equityFundraising.connect(user2).setReferralFee(newFee))
                .to.be.reverted;

            await equityFundraising.setReferralFee(newFee);
            expect(await equityFundraising.referralFee()).to.equal(newFee);
        });

        it("Should set ForcefiStaking address", async function () {
            // Try to call with invalid owner address
            await expect(equityFundraising.connect(user2).setForcefiStakingAddress(forcefiStaking.getAddress()))
                .to.be.reverted;

            await expect(
                equityFundraising.setForcefiStakingAddress(forcefiStaking.getAddress())
            ).to.be.revertedWith("ForceFi staking address can only be set once");
        });

        it("Should set successful fundraise fee address", async function () {

            // Try to call with invalid owner address
            await expect(equityFundraising.connect(user2).setSuccessfulFundraisingFeeAddress(user1.address))
                .to.be.reverted;
            
            await equityFundraising.setSuccessfulFundraisingFeeAddress(user1.address);
            expect(await equityFundraising.successfulFundraiseFeeAddress()).to.equal(user1.address);
        });

        it("Should correctly return whitelisted tokens for a campaign", async function () {
            // Create a new campaign first
            const { campaignId } = await createNewFundraising(
                equityFundraising,
                projectToken,
                investmentToken,
                {},
                user1
            );
            
            // Get whitelisted tokens for the campaign
            const whitelistedTokens = await equityFundraising.getWhitelistedTokens(campaignId);
            
            // Verify the investment token is in the list
            expect(whitelistedTokens).to.have.lengthOf(1);
            expect(whitelistedTokens[0]).to.equal(await investmentToken.getAddress());
        });
    });

    describe("Campaign Creation and Investment", function () {
        it("Should create a fundraising campaign with correct parameters", async function () {
            const fundraisingInstance = await equityFundraising.getFundraisingInstance(capturedValue);
            expect(fundraisingInstance.owner).to.equal(owner.address);
            expect(fundraisingInstance.campaignHardCap).to.equal(campaignLimit);
            expect(fundraisingInstance.rate).to.equal(100);
            expect(fundraisingInstance.rateDelimiter).to.equal(100);
            expect(fundraisingInstance.privateFundraising).to.be.false;
        });

        it("Should allow investment in campaign", async function () {
            const investAmount = 100;

            await investmentToken.approve(equityFundraising.getAddress(), investAmount);
            
            // Invest and verify event
            await expect(equityFundraising.invest(investAmount, investmentToken.getAddress(), capturedValue))
                .to.emit(equityFundraising, 'Invested')
                .withArgs(owner.address, investAmount, await investmentToken.getAddress(), capturedValue);
            
            const finalBalance = await equityFundraising.getIndividualBalanceForTokenAndAddress(capturedValue, owner.address, investmentToken.getAddress());

            expect(finalBalance).to.equal(investAmount);
        });

        it("Should respect min and max ticket limits", async function () {
            const tooSmallAmount = 50;  // Less than min ticket limit
            const tooLargeAmount = 400; // More than max ticket limit
            
            await investmentToken.approve(equityFundraising.getAddress(), tooLargeAmount);
            
            await expect(
                equityFundraising.invest(tooSmallAmount, investmentToken.getAddress(), capturedValue)
            ).to.be.revertedWith("Amount should be more than campaign min ticket limit");
            
            await expect(
                equityFundraising.invest(tooLargeAmount, investmentToken.getAddress(), capturedValue)
            ).to.be.revertedWith("Amount should be less than campaign max ticket limit");
        });

        it("Should handle private campaign whitelist correctly", async function () {            
            // Set user2 as staker, who is eligable to invest into sales
            await forcefiToken.transfer(user2.address, minStakingAmount);
            await forcefiToken.connect(user2).approve(forcefiStaking.getAddress(), minStakingAmount);
            await forcefiStaking.connect(user2).stake(minStakingAmount, user2.address);

            const investAmount = 100;
            await investmentToken.connect(user2).approve(equityFundraising.getAddress(), investAmount);
            
            // Try to invest in private campaign without being whitelisted
            await expect(
                equityFundraising.connect(user2).invest(investAmount, investmentToken.getAddress(), privateCampaignCapturedValue)
            ).to.be.revertedWith("not whitelisted address");

            // Try to invest in private campaign without being whitelisted
            await expect(
                equityFundraising.connect(user2).invest(investAmount, investmentToken.getAddress(), privateCampaignCapturedValue)
            ).to.be.revertedWith("not whitelisted address");

            await expect(
                equityFundraising.connect(user2).investWithNativeCurrency(privateCampaignCapturedValue, {
                    value: ethers.parseEther("0.0000000045")
                })
            ).to.be.revertedWith("not whitelisted address");
            
            // Try to call with invalid owner address
            await expect(equityFundraising.connect(user2).addWhitelistAddress([user2.address], privateCampaignCapturedValue))
                .to.be.revertedWith("Not an owner of a fundraising");

            // Add to whitelist
            await equityFundraising.addWhitelistAddress([user2.address], privateCampaignCapturedValue);
            
            await investmentToken.transfer(user2.address, investAmount);
            // Should now be able to invest
            await equityFundraising.connect(user2).invest(investAmount, investmentToken.getAddress(), privateCampaignCapturedValue);
            
            await equityFundraising.connect(user2).investWithNativeCurrency(privateCampaignCapturedValue, {
                    value: ethers.parseEther("0.00000025")
                })
            
            const balance = await equityFundraising.connect(user2).getIndividualBalanceForTokenAndAddress(privateCampaignCapturedValue, user2.address, investmentToken.getAddress());
            expect(balance).to.be.gt(0);
        });

        it("Should create fundraising when project has creation token without fee", async function () {
            
            const currentTime = await getCurrentTime();
            const fundraisingData = {
                _label: "token test",
                _vestingStart: currentTime,
                _cliffPeriod: 0,
                _vestingPeriod: 0,
                _releasePeriod: 0,
                _tgePercent: 0,
                _totalCampaignLimit: 300,
                _rate: 100,
                _rateDelimiter: 100,
                _startDate: currentTime,
                _endDate: currentTime + 1000,
                _isPrivate: false,
                _campaignMinTicketLimit: 100,
                _campaignMaxTicketLimit: 300
            };

            await projectToken.approve(equityFundraising.getAddress(), fundraisingData._totalCampaignLimit);
            
            const attachedERC20Address = [await investmentToken.getAddress()];

            // Should fail creating fundraising if fee is not paid or creation token is not minted
            // Set fee amount to 1 ETH
            await equityFundraising.setFeeAmount(ethers.parseEther("1"));

            await expect(equityFundraising.createFundraising(
                fundraisingData,
                attachedERC20Address,
                user1.getAddress(),
                "TestProject",
                projectToken.getAddress(),
                [],
                false,
                { value: ethers.parseEther("0.5") } // Send invalid fee amount                
            )).to.be.revertedWith("Invalid fee value or no creation token available");
            
            // Should not require fee payment when creating fundraising because of creation token
            // Mock the ForcefiPackage hasCreationToken to return true for our test
            await forcefiPackage.ownerMintToken(owner.address, "TestProject");

            await expect(equityFundraising.createFundraising(
                fundraisingData,
                attachedERC20Address,
                user1.getAddress(),
                "TestProject",
                projectToken.getAddress(),
                [],
                false,
                { value: ethers.parseEther("0.5") } // Send invalid fee amount
            )).to.emit(equityFundraising, 'FundraisingCreated');
            
            // Verify campaign was created with correct parameters
            const event = await equityFundraising.queryFilter(equityFundraising.filters.FundraisingCreated());
            const campaignId = event[event.length - 1].args[1];
            
            const fundraisingInstance = await equityFundraising.getFundraisingInstance(campaignId);
            expect(fundraisingInstance.owner).to.equal(owner.address);
            expect(fundraisingInstance.campaignHardCap).to.equal(fundraisingData._totalCampaignLimit);
            expect(fundraisingInstance.privateFundraising).to.be.false;
        });

        it("Should allow investment below min ticket when remaining amount is less than min ticket", async function () {
            const { campaignId } = await createNewFundraising(
                equityFundraising,
                projectToken,
                investmentToken,
                {
                    _totalCampaignLimit: 150, // Small cap for testing
                    _campaignMinTicketLimit: 100,
                    _campaignMaxTicketLimit: 150
                },
                user1
            );

            // First invest 100 tokens (meets min ticket requirement)
            await investmentToken.approve(equityFundraising.getAddress(), 100);
            await equityFundraising.invest(100, investmentToken.getAddress(), campaignId);

            // Now try to invest the remaining 50 tokens (below min ticket but allowed because it's the remaining amount)
            await investmentToken.approve(equityFundraising.getAddress(), 50);
            await expect(
                equityFundraising.invest(50, investmentToken.getAddress(), campaignId)
            ).to.not.be.reverted;

            // Verify the total invested amount
            const fundraisingInstance = await equityFundraising.getFundraisingInstance(campaignId);
            expect(fundraisingInstance.totalFundraised).to.equal(150);
        });

        it("Should enforce minimum threshold requirement for closing", async function () {
            const { campaignId } = await createNewFundraising(
                equityFundraising,
                projectToken,
                investmentToken,
                {
                    _totalCampaignLimit: 1000,
                    _campaignMinTicketLimit: 100,
                    _campaignMaxTicketLimit: 1000
                },
                user1
            );

            // Invest less than threshold (less than 70% of 1000)
            const investAmount = 500; // Only 50%
            await investmentToken.approve(equityFundraising.getAddress(), investAmount);
            await equityFundraising.invest(investAmount, investmentToken.getAddress(), campaignId);

            // Fast forward past end date + reclaim window
            await ethers.provider.send("evm_increaseTime", [1100]);
            await ethers.provider.send("evm_mine");

            // Try to close campaign that didn't reach threshold
            await expect(
                equityFundraising.closeCampaign(campaignId)
            ).to.be.revertedWith("Campaign didn't reach minimal threshold");
        });

        it("Should handle fee distribution with unset addresses", async function () {
            const { campaignId } = await createNewFundraising(
                equityFundraising,
                projectToken,
                investmentToken,
                {
                    _totalCampaignLimit: 1000,
                    _campaignMinTicketLimit: 100,
                    _campaignMaxTicketLimit: 1000
                }
            );

            // Invest enough to meet threshold
            const investAmount = 800;
            await investmentToken.approve(equityFundraising.getAddress(), investAmount);
            await equityFundraising.invest(investAmount, investmentToken.getAddress(), campaignId);

            // Set all addresses to zero
            await equityFundraising.setSuccessfulFundraisingFeeAddress(ethers.ZeroAddress);
            await equityFundraising.setCuratorsContractAddress(ethers.ZeroAddress);

            // Record initial balance
            const initialBalance = await investmentToken.balanceOf(owner.address);

            // Fast forward and close campaign
            await ethers.provider.send("evm_increaseTime", [1100]);
            await ethers.provider.send("evm_mine");

            // Should close successfully even with unset addresses
            await expect(equityFundraising.closeCampaign(campaignId))
                .to.emit(equityFundraising, 'CampaignClosed');

            // Verify campaign closed
            const finalCampaign = await equityFundraising.getFundraisingInstance(campaignId);
            expect(finalCampaign.campaignClosed).to.be.true;

            // Verify owner received funds (since no fees were distributed)
            const finalBalance = await investmentToken.balanceOf(owner.address);
            expect(finalBalance).to.be.gt(initialBalance);
        });

        it("Should handle zero curator fee percentage", async function () {
            const { campaignId } = await createNewFundraising(
                equityFundraising,
                projectToken,
                investmentToken,
                {
                    _totalCampaignLimit: 1000,
                    _campaignMinTicketLimit: 100,
                    _campaignMaxTicketLimit: 1000
                },
                user1
            );

            // Setup mock curator contract to return 0 percentage
            const MockCuratorContract = await ethers.getContractFactory("MockCuratorContract");
            const zeroCuratorContract = await MockCuratorContract.deploy();
            // await zeroCuratorContract.setPercentage(0); // Assuming mock has this function
            await equityFundraising.setCuratorsContractAddress(zeroCuratorContract.getAddress());

            // Invest and close campaign
            const investAmount = 800;
            await investmentToken.approve(equityFundraising.getAddress(), investAmount);
            await equityFundraising.invest(investAmount, investmentToken.getAddress(), campaignId);

            await ethers.provider.send("evm_increaseTime", [1100]);
            await ethers.provider.send("evm_mine");

            // Should close successfully with zero curator fee
            await expect(equityFundraising.closeCampaign(campaignId))
                .to.emit(equityFundraising, 'CampaignClosed');
        });

        it("Should distribute curator fees correctly when percentage is set", async function () {
            const { campaignId } = await createNewFundraising(
                equityFundraising,
                projectToken,
                investmentToken,
                {
                    _totalCampaignLimit: 1000,
                    _campaignMinTicketLimit: 100,
                    _campaignMaxTicketLimit: 1000
                },
                user1
            );

            // Invest enough to meet threshold
            const investAmount = 800;
            await investmentToken.approve(equityFundraising.getAddress(), investAmount);
            await equityFundraising.invest(investAmount, investmentToken.getAddress(), campaignId);

            // Set curator contract and percentage
            await equityFundraising.setCuratorsContractAddress(mockCuratorContract.getAddress());
            await mockCuratorContract.setTotalPercentage(campaignId, 50); // Set 50% curator share

            // Record initial balances
            const initialCuratorBalance = await investmentToken.balanceOf(mockCuratorContract.getAddress());

            // Fast forward and close campaign
            await ethers.provider.send("evm_increaseTime", [1100]);
            await ethers.provider.send("evm_mine");

            // Close campaign
            await equityFundraising.closeCampaign(campaignId);

            // Verify curator fee distribution
            const finalCuratorBalance = await investmentToken.balanceOf(mockCuratorContract.getAddress());
            expect(finalCuratorBalance).to.be.gt(initialCuratorBalance);

            // Verify received fee in mock contract
            const receivedFee = await mockCuratorContract.getReceivedFee(investmentToken.getAddress(), campaignId);
            expect(receivedFee).to.be.gt(0);
        });

        it("Should skip curator fee distribution when percentage is zero", async function () {
            const { campaignId } = await createNewFundraising(
                equityFundraising,
                projectToken,
                investmentToken,
                {
                    _totalCampaignLimit: 1000,
                    _campaignMinTicketLimit: 100,
                    _campaignMaxTicketLimit: 1000
                },
                user1
            );

            // Invest enough to meet threshold
            const investAmount = 800;
            await investmentToken.approve(equityFundraising.getAddress(), investAmount);
            await equityFundraising.invest(investAmount, investmentToken.getAddress(), campaignId);

            // Set curator contract but keep percentage at 0
            await equityFundraising.setCuratorsContractAddress(mockCuratorContract.getAddress());
            await mockCuratorContract.setTotalPercentage(campaignId, 0);

            // Record initial balance
            const initialCuratorBalance = await investmentToken.balanceOf(mockCuratorContract.getAddress());

            // Fast forward and close campaign
            await ethers.provider.send("evm_increaseTime", [1100]);
            await ethers.provider.send("evm_mine");

            // Close campaign
            await equityFundraising.closeCampaign(campaignId);

            // Verify no curator fee was distributed
            const finalCuratorBalance = await investmentToken.balanceOf(mockCuratorContract.getAddress());
            expect(finalCuratorBalance).to.equal(initialCuratorBalance);

            // Verify no fee was received in mock contract
            const receivedFee = await mockCuratorContract.getReceivedFee(investmentToken.getAddress(), campaignId);
            expect(receivedFee).to.equal(0);
        });

        it("Should prevent token reclaim before campaign end", async function () {
            const { campaignId } = await createNewFundraising(
                equityFundraising,
                projectToken,
                investmentToken,
                {
                    _totalCampaignLimit: 1000,
                    _campaignMinTicketLimit: 100,
                    _campaignMaxTicketLimit: 1000,
                    _startDate: (await getCurrentTime()),
                    _endDate: (await getCurrentTime()) + 1000
                },
                user1
            );
        
            // Invest some tokens
            const investAmount = 100;
            await investmentToken.approve(equityFundraising.getAddress(), investAmount);
            await equityFundraising.invest(investAmount, investmentToken.getAddress(), campaignId);
        
            // Try to reclaim before end date
            await expect(
                equityFundraising.reclaimTokens(campaignId)
            ).to.be.revertedWith("Campaign has not ended");
        
            // Fast forward past end date and verify reclaim works
            await ethers.provider.send("evm_increaseTime", [1100]);
            await ethers.provider.send("evm_mine");
        
            await expect(
                equityFundraising.reclaimTokens(campaignId)
            ).to.not.be.reverted;
        }); 
    });

    describe("Fee Calculations and Distribution", function () {
        let campaignId;
        beforeEach(async function() {
            // Create new fundraising instance for fee distribution test
            const result = await createNewFundraising(
                equityFundraising,
                projectToken,
                investmentToken,
                {
                    _totalCampaignLimit: 300,
                    _campaignMinTicketLimit: 100,
                    _campaignMaxTicketLimit: 300,
                    _campaignSoftCap: 300
                },
                user1
            );
            campaignId = result.campaignId;
        });

        it("Should distribute fees correctly on campaign close", async function () {
            const investAmount = 300;
            await investmentToken.approve(equityFundraising.getAddress(), investAmount);
            await equityFundraising.invest(investAmount, investmentToken.getAddress(), campaignId);

            // Set fee recipients
            await equityFundraising.setSuccessfulFundraisingFeeAddress(user1.address);
            await equityFundraising.setCuratorsContractAddress(mockCuratorContract.getAddress());

            // Record balances before closing
            const initialUser1Balance = await investmentToken.balanceOf(user1.address);
            const initialStakingBalance = await investmentToken.balanceOf(forcefiStaking.getAddress());

            // Fast forward and close campaign
            await ethers.provider.send("evm_increaseTime", [5100]);
            await ethers.provider.send("evm_mine");

            // Try to close campaign with invalid caller address
            await expect(
                equityFundraising.connect(user2).closeCampaign(campaignId)
            ).to.be.revertedWith("Not an owner of a fundraising");

            await equityFundraising.closeCampaign(campaignId);

            // Check fee distribution
            const finalUser1Balance = await investmentToken.balanceOf(user1.address);
            const finalStakingBalance = await investmentToken.balanceOf(forcefiStaking.getAddress());

            expect(finalUser1Balance).to.be.gt(initialUser1Balance);
            expect(finalStakingBalance).to.be.gt(initialStakingBalance);
        });
    });

    describe("Vesting Functionality", function () {
        let vestingCampaignId;

        beforeEach(async function () {
            const currentTime = Math.floor(Date.now() / 1000);
            
            // Create vesting campaign using utility function
            const { campaignId } = await createNewFundraising(
                equityFundraising,
                projectToken,
                investmentToken,
                {
                    _vestingStart: currentTime,
                    _cliffPeriod: 1000,
                    _vestingPeriod: 5000,
                    _releasePeriod: 1000,
                    _tgePercent: 20,
                    _campaignMaxTicketLimit: 1000 // Increased for vesting tests
                },
                user1
            );
            vestingCampaignId = campaignId;
        });

        it("Should calculate releasable amount correctly during vesting", async function () {
            const investAmount = 200;
            await investmentToken.approve(equityFundraising.getAddress(), investAmount);
            await equityFundraising.invest(investAmount, investmentToken.getAddress(), vestingCampaignId);

            // Fast forward past cliff period
            await ethers.provider.send("evm_increaseTime", [1100]);
            await ethers.provider.send("evm_mine");

            const releasableAmount = await equityFundraising.computeReleasableAmount(vestingCampaignId);
            expect(releasableAmount).to.be.gt(0);
        });

        it("Should return correct vesting plan details", async function () {
            const vestingPlan = await equityFundraising.getVestingPlan(vestingCampaignId);
            
            // Verify all vesting parameters match what we set during campaign creation
            expect(vestingPlan.cliffPeriod).to.equal(1000);
            expect(vestingPlan.vestingPeriod).to.equal(5000);
            expect(vestingPlan.releasePeriod).to.equal(1000);
            expect(vestingPlan.tgePercent).to.equal(20);
        });

        it("Should prevent token release before vesting start time", async function () {
            const currentTime = await getCurrentTime();
            const futureStartTime = currentTime + 2000; // Set vesting to start in future
            
            // Create campaign with future vesting start
            const { campaignId } = await createNewFundraising(
                equityFundraising,
                projectToken,
                investmentToken,
                {
                    _vestingStart: futureStartTime,
                    _cliffPeriod: 1000,
                    _vestingPeriod: 5000,
                    _releasePeriod: 1000,
                    _tgePercent: 20,
                    _campaignMaxTicketLimit: 1000
                },
                user1
            );

            // Make investment
            const investAmount = 200;
            await investmentToken.approve(equityFundraising.getAddress(), investAmount);
            await equityFundraising.invest(investAmount, investmentToken.getAddress(), campaignId);

            // Try to compute releasable amount before vesting starts
            await expect(
                equityFundraising.computeReleasableAmount(campaignId)
            ).to.be.revertedWith("TokenVesting: this vesting has not started yet");

            // Fast forward past vesting start
            await ethers.provider.send("evm_increaseTime", [2100]); // Past vesting start
            await ethers.provider.send("evm_mine");

            // Should now be able to compute releasable amount
            const releasableAmount = await equityFundraising.computeReleasableAmount(campaignId);
            expect(releasableAmount).to.be.gt(0);
        });

        it("Should prevent token claims before campaign is closed", async function () {
            // Create campaign 
            const { campaignId } = await createNewFundraising(
                equityFundraising,
                projectToken,
                investmentToken,
                {
                    _totalCampaignLimit: 1000,
                    _campaignMinTicketLimit: 100,
                    _campaignMaxTicketLimit: 1000
                },
                user1
            );

            // Invest less than threshold
            const investAmount = 1000;
            await investmentToken.approve(equityFundraising.getAddress(), investAmount);
            await equityFundraising.invest(investAmount, investmentToken.getAddress(), campaignId);

            // Try to claim before end date
            await expect(
                equityFundraising.claimTokens(campaignId)
            ).to.be.revertedWith("Campaign isnt closed");

            // Fast forward past end date but with insufficient investment
            await ethers.provider.send("evm_increaseTime", [1100]);
            await ethers.provider.send("evm_mine");
        });

        
        it("Should create fundraising campaign with price of 0.0045, close campaign, claim tokens by investor", async function () {
            const mockOracle = await ethers.deployContract("MockedV3Aggregator", [
                8, // 8 decimals
                100000000 // $1.00 with 8 decimals
            ]);

            const ethDataFeed = await ethers.deployContract("MockedV3Aggregator", [
                18, // 8 decimals
                100000000 // $1.00 with 8 decimals
            ]);

            const currentTime = (await ethers.provider.getBlock('latest')).timestamp;
            
            // Create campaign with rate 45 and rateDelimiter 10000 to get 0.0045 (45/10000)
            const campaignData = {
                _label: "low price test",
                _vestingStart: currentTime,
                _cliffPeriod: 0,
                _vestingPeriod: 0,
                _releasePeriod: 0,
                _tgePercent: 0,
                _totalCampaignLimit: 1000,
                _rate: 45,           // Numerator
                _rateDelimiter: 10000,  // Denominator: 45/10000 = 0.0045
                _startDate: currentTime,
                _endDate: currentTime + 1000,
                _isPrivate: false,
                _campaignMinTicketLimit: 100,
                _campaignMaxTicketLimit: 1000
            };

            equityFundraising.whitelistTokenForInvestment(investmentToken.getAddress(), mockOracle.getAddress())
            await equityFundraising.whitelistNativeCurrencyForInvestment(ethDataFeed.getAddress());

            const attachedERC20Address = [await investmentToken.getAddress()];
            await projectToken.approve(equityFundraising.getAddress(), campaignData._totalCampaignLimit);
            
            const tx = await equityFundraising.createFundraising(
                campaignData,
                attachedERC20Address,
                ethers.ZeroAddress,
                "LowPriceTest",
                projectToken.getAddress(),
                [],
                true // Include native currency
            );

            const receipt = await tx.wait();
            const event = receipt.logs.find(x => x.fragment && x.fragment.name === 'FundraisingCreated');
            const newCampaignId = event.args[1];

            // Verify campaign was created with correct rate
            const fundraisingInstance = await equityFundraising.getFundraisingInstance(newCampaignId);
            expect(fundraisingInstance.rate).to.equal(45);
            expect(fundraisingInstance.rateDelimiter).to.equal(10000);
              // Test that investment calculation works correctly with low price
            const investAmount = 10; // Invest 10 tokens worth
            
            // Calculate required ETH for investment
            const ethPrice = await ethDataFeed.latestAnswer();
            const requiredEth = (Number(ethPrice) * Number(campaignData._rate) * Number(investAmount))
            
            // Try to invest with zero ETH value - this should fail
            await expect(
                equityFundraising.connect(user1).investWithNativeCurrency(newCampaignId, {
                    value: 0 // Zero ETH value
                })
            ).to.be.revertedWith("Must send ETH to invest");

            // Should be able to invest with native currency
            await expect(
                equityFundraising.connect(user1).investWithNativeCurrency(newCampaignId, {
                    value: requiredEth
                })
            ).to.emit(equityFundraising, 'Invested');
            
            // Verify investment was recorded
            const nativeBalance = await equityFundraising.connect(user1).getNativeCurrencyBalance(newCampaignId);
            expect(nativeBalance).to.equal(requiredEth);

            const getTotalNativeCurrencyRaised = await equityFundraising.getTotalNativeCurrencyRaised(newCampaignId);
            expect(getTotalNativeCurrencyRaised).to.equal(requiredEth);

            // Fast forward and close campaign
            await ethers.provider.send("evm_increaseTime", [5100]);
            await ethers.provider.send("evm_mine");

            // Try to close campaign with invalid caller address
            await expect(
                equityFundraising.connect(user2).closeCampaign(newCampaignId)
            ).to.be.revertedWith("Not an owner of a fundraising");
            
            // Check balance before closing
            const initialOwnerBalance = await ethers.provider.getBalance(owner.address);

            const closeTx = await equityFundraising.closeCampaign(newCampaignId);
            const closeReceipt = await closeTx.wait();
            const gasUsed = closeReceipt.gasUsed * closeReceipt.gasPrice;

            // Verify caller balance after closing the campaign
            const finalOwnerBalance = await ethers.provider.getBalance(owner.address);
            
            // Calculate expected balance after fees
            // Fee calculation: Tier 1 fee = 5% for investments < 1M tokens
            const totalInvested = BigInt(requiredEth);
            const feePercentage = 5; // Tier 1 fee: 5%
            const totalFee = totalInvested * BigInt(feePercentage) / BigInt(100);
            
            // Staking fee distribution: 30% of base fee (3/10)
            // Platform, curator, and referral fees are 0 (addresses not set)
            const stakingFee = totalFee * BigInt(3) / BigInt(10);
            
            // Owner receives: totalInvested - stakingFee - gasUsed
            const expectedOwnerReceived = totalInvested - stakingFee;
            const expectedFinalBalance = initialOwnerBalance + expectedOwnerReceived - gasUsed;
            
            expect(finalOwnerBalance).to.equal(expectedFinalBalance);

            // Claim tokens by investor
            await equityFundraising.connect(user1).claimTokens(newCampaignId);
            const userTokenBalance = await projectToken.balanceOf(user1.address);
            expect(userTokenBalance).to.equal(1000);

            // Try to claim again - should fail as all tokens have been claimed
            await expect(
                equityFundraising.connect(user1).claimTokens(newCampaignId)
            ).to.be.revertedWith("TokenVesting: cannot release tokens, no vested tokens");            
        });        it("Should create fundraising campaign with price of 0.0045, add staking and curator address, then check releaseUndistributedFees functionality", async function () {
            const mockOracle = await ethers.deployContract("MockedV3Aggregator", [
                8, // 8 decimals
                100000000 // $1.00 with 8 decimals
            ]);

            const ethDataFeed = await ethers.deployContract("MockedV3Aggregator", [
                18, // 8 decimals
                100000000 // $1.00 with 8 decimals
            ]);

            const currentTime = (await ethers.provider.getBlock('latest')).timestamp;
            
            // Create campaign with rate 45 and rateDelimiter 10000 to get 0.0045 (45/10000)
            const campaignData = {
                _label: "low price test",
                _vestingStart: currentTime,
                _cliffPeriod: 0,
                _vestingPeriod: 0,
                _releasePeriod: 0,
                _tgePercent: 0,
                _totalCampaignLimit: 1000,
                _rate: 45,           // Numerator
                _rateDelimiter: 10000,  // Denominator: 45/10000 = 0.0045
                _startDate: currentTime,
                _endDate: currentTime + 1000,
                _isPrivate: false,
                _campaignMinTicketLimit: 100,
                _campaignMaxTicketLimit: 1000
            };

            equityFundraising.whitelistTokenForInvestment(investmentToken.getAddress(), mockOracle.getAddress())
            await equityFundraising.whitelistNativeCurrencyForInvestment(ethDataFeed.getAddress());

            const attachedERC20Address = [await investmentToken.getAddress()];
            await projectToken.approve(equityFundraising.getAddress(), campaignData._totalCampaignLimit);

            // Set fee recipients
            await equityFundraising.setSuccessfulFundraisingFeeAddress(user3.address);
            await equityFundraising.setCuratorsContractAddress(mockCuratorContract.getAddress());
            
            const tx = await equityFundraising.createFundraising(
                campaignData,
                attachedERC20Address,
                ethers.ZeroAddress,
                "LowPriceTest",
                projectToken.getAddress(),
                [],
                true // Include native currency
            );

            const receipt = await tx.wait();
            const event = receipt.logs.find(x => x.fragment && x.fragment.name === 'FundraisingCreated');
            const newCampaignId = event.args[1];

            // Verify campaign was created with correct rate
            const fundraisingInstance = await equityFundraising.getFundraisingInstance(newCampaignId);
            expect(fundraisingInstance.rate).to.equal(45);
            expect(fundraisingInstance.rateDelimiter).to.equal(10000);
              // Test that investment calculation works correctly with low price
            const investAmount = 10; // Invest 10 tokens worth
            
            // Calculate required ETH for investment
            const ethPrice = await ethDataFeed.latestAnswer();
            const requiredEth = (Number(ethPrice) * Number(campaignData._rate) * Number(investAmount))
            
            // Should be able to invest with native currency
            await expect(
                equityFundraising.connect(user1).investWithNativeCurrency(newCampaignId, {
                    value: requiredEth
                })
            ).to.emit(equityFundraising, 'Invested');

            // Fast forward and close campaign
            await ethers.provider.send("evm_increaseTime", [5100]);
            await ethers.provider.send("evm_mine");

            const initialOwnerBalance = await ethers.provider.getBalance(owner.address);

            // Check forcefiStaking address balance in native currency before closing
            const initialStakingBalance = await ethers.provider.getBalance(forcefiStaking.getAddress()); 

            const closeTx = await equityFundraising.closeCampaign(newCampaignId);
            const closeReceipt = await closeTx.wait();
            const gasUsed = closeReceipt.gasUsed * closeReceipt.gasPrice;

            // Verify caller balance after closing the campaign
            const finalOwnerBalance = await ethers.provider.getBalance(owner.address);

            // Verify forcefiStaking address balance in native currency after closing
            const finalStakingBalance = await ethers.provider.getBalance(forcefiStaking.getAddress());
            expect(finalStakingBalance).to.be.gt(initialStakingBalance);
            
            // Calculate expected balance after fees
            // Fee calculation: Tier 1 fee = 5% for investments < 1M tokens
            const totalInvested = BigInt(requiredEth);
            const feePercentage = 5; // Tier 1 fee: 5%
            const totalFee = totalInvested * BigInt(feePercentage) / BigInt(100);
            
            // Fee distribution:
            // - Platform fee (user3.address is set): 20% of base fee (1/5)
            // - Staking fee (forcefiStakingAddress is set): 30% of base fee (3/10)  
            // - Curator fee: 0% (curator address set but percentage is 0%)
            // - Referral fee: 0% (no referral address set)
            
            const platformFee = totalFee / BigInt(5);     // 20% of base fee
            const stakingFee = totalFee * BigInt(3) / BigInt(10);  // 30% of base fee
            const curatorFee = BigInt(0);                 // 0% since curator percentage is 0
            const referralFee = BigInt(0);                // 0% since no referral address
            
            const totalDistributedFees = platformFee + stakingFee + curatorFee + referralFee;
            
            // Owner receives: totalInvested - totalDistributedFees - gasUsed
            const expectedOwnerReceived = totalInvested - totalDistributedFees;
            const expectedFinalBalance = initialOwnerBalance + expectedOwnerReceived - gasUsed;
            
            expect(finalOwnerBalance).to.equal(expectedFinalBalance);

            await expect(equityFundraising.releaseUndistributedFees())
                .to.be.revertedWith("No undistributed fees for this address");
        });

        it("Should create fundraising campaign with price of 0.0045, fail campaign, reclaim ETH", async function () {
            const mockOracle = await ethers.deployContract("MockedV3Aggregator", [
                8, // 8 decimals
                100000000 // $1.00 with 8 decimals
            ]);

            const ethDataFeed = await ethers.deployContract("MockedV3Aggregator", [
                18, // 8 decimals
                100000000 // $1.00 with 8 decimals
            ]);

            const currentTime = (await ethers.provider.getBlock('latest')).timestamp;
            
            // Create campaign with rate 45 and rateDelimiter 10000 to get 0.0045 (45/10000)
            const campaignData = {
                _label: "low price test",
                _vestingStart: currentTime,
                _cliffPeriod: 0,
                _vestingPeriod: 0,
                _releasePeriod: 0,
                _tgePercent: 0,
                _totalCampaignLimit: 1000,
                _rate: 45,           // Numerator
                _rateDelimiter: 10000,  // Denominator: 45/10000 = 0.0045
                _startDate: currentTime,
                _endDate: currentTime + 1000,
                _isPrivate: false,
                _campaignMinTicketLimit: 100,
                _campaignMaxTicketLimit: 1000
            };

            equityFundraising.whitelistTokenForInvestment(investmentToken.getAddress(), mockOracle.getAddress())
            await equityFundraising.whitelistNativeCurrencyForInvestment(ethDataFeed.getAddress());

            const attachedERC20Address = [await investmentToken.getAddress()];
            await projectToken.approve(equityFundraising.getAddress(), campaignData._totalCampaignLimit);
            
            const tx = await equityFundraising.createFundraising(
                campaignData,
                attachedERC20Address,
                ethers.ZeroAddress,
                "LowPriceTest",
                projectToken.getAddress(),
                [],
                true // Include native currency
            );

            const receipt = await tx.wait();
            const event = receipt.logs.find(x => x.fragment && x.fragment.name === 'FundraisingCreated');
            const newCampaignId = event.args[1];

            // Verify campaign was created with correct rate
            const fundraisingInstance = await equityFundraising.getFundraisingInstance(newCampaignId);
            expect(fundraisingInstance.rate).to.equal(45);
            expect(fundraisingInstance.rateDelimiter).to.equal(10000);
              // Test that investment calculation works correctly with low price
            const investAmount = 1; // Invest 10 tokens worth
            
            // Calculate required ETH for investment
            const ethPrice = await ethDataFeed.latestAnswer();
            const requiredEth = (Number(ethPrice) * Number(campaignData._rate) * Number(investAmount))
            
            // Try to invest with zero ETH value - this should fail
            await expect(
                equityFundraising.connect(user1).investWithNativeCurrency(newCampaignId, {
                    value: 0 // Zero ETH value
                })
            ).to.be.revertedWith("Must send ETH to invest");

            // Should be able to invest with native currency
            await expect(
                equityFundraising.connect(user1).investWithNativeCurrency(newCampaignId, {
                    value: requiredEth
                })
            ).to.emit(equityFundraising, 'Invested');
            
            // Fast forward and close campaign
            await ethers.provider.send("evm_increaseTime", [5100]);
            await ethers.provider.send("evm_mine");

            await expect(equityFundraising.closeCampaign(newCampaignId))
                .to.be.revertedWith("Campaign didn't reach minimal threshold");

            // Reclaim ETH by investor
            const initialUserBalance = await ethers.provider.getBalance(user1.address);
            const reclaimTx = await equityFundraising.connect(user1).reclaimTokens(newCampaignId);
            const reclaimReceipt = await reclaimTx.wait();
            const gasUsed = reclaimReceipt.gasUsed * reclaimReceipt.gasPrice;
            const finalUserBalance = await ethers.provider.getBalance(user1.address);

            const expectedFinalBalance = initialUserBalance + BigInt(requiredEth) - gasUsed;
            expect(finalUserBalance).to.equal(expectedFinalBalance);

            // Balance before unlocking funds
            const initialOwnerTokenBalance = await projectToken.balanceOf(owner.address);
            // Unlock funds by owner
            await equityFundraising.unlockFundsFromCampaign(newCampaignId);
            const ownerTokenBalance = await projectToken.balanceOf(owner.address);
            expect(ownerTokenBalance).to.equal(Number(initialOwnerTokenBalance) + 1000);
         
        });
    });
});