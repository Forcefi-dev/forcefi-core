// const { expect } = require("chai");
//
// const getCurrentTime = async () => {
//     const currentBlock = await ethers.provider.getBlock("latest");
//     return currentBlock.timestamp;
// }
//
// describe("EquityFundraising", function () {
//
//     let equityFundraising;
//     let owner;
//     let user1;
//     let user2;
//     let user3;
//     let user4;
//     let mockedLzAddress;
//     let mainWalletAddressMock;
//     let erc20Token;
//     let investmentToken;
//     let investmentToken2;
//     let projectToken;
//     let forcefiPackage;
//
//     let capturedValue;
//     let privateCampaignCapturedValue;
//     let treshholdedCapturedValue;
//     let newFundraisingCampaign;
//     const campaignLimit = 300;
//     const projectName = "Tesla"
//     const additionalTokens = 10000;
//     const referralFee = 5;
//
//     const startDateTimestamp = getCurrentTime()
//     const getEndDate = async () => {
//         const currentTime = await getCurrentTime();
//         return  currentTime + 5000;
//     };
//     const endDate = getEndDate();
//
//     const _fundraisingData = {
//         _label: "simple vesting",
//         _vestingStart: 0,
//         _cliffPeriod: 0,
//         _vestingPeriod: 0,
//         _releasePeriod: 0,
//         _tgePercent: 0,
//         _totalCampaignLimit: campaignLimit,
//         _campaignSoftCap: 250,
//         _rate: 100,
//         _rateDelimiter: 100,
//         _startDate: startDateTimestamp,
//         _endDate: endDate,
//         _isPrivate: false,
//         _campaignMinTicketLimit: 100,
//         _campaignMaxTicketLimit: 300
//     }
//
//     const _privateCampaignFundraisingData = {
//         _label: "simple vesting",
//         _vestingStart: 0,
//         _cliffPeriod: 0,
//         _vestingPeriod: 0,
//         _releasePeriod: 0,
//         _tgePercent: 0,
//         _totalCampaignLimit: campaignLimit,
//         _campaignSoftCap: 200,
//         _rate: 1,
//         _rateDelimiter: 4,
//         _startDate: startDateTimestamp,
//         _endDate: endDate,
//         _isPrivate: true,
//         _campaignMinTicketLimit: 100,
//         _campaignMaxTicketLimit: 200
//     }
//
//     const minStakingAmount = 100;
//     const investorTreshhold = 7500;
//
//     beforeEach(async function () {
//
//         const MockOracle = await ethers.getContractFactory("MockV3Aggregator");
//         const mockOracle = await MockOracle.deploy(
//             "18", // decimals
//             "1000"// initialAnswer
//         );
//
//         [owner, user1, user2, user3, user4, mainWalletAddressMock, mockedLzAddress] = await ethers.getSigners();
//         equityFundraising = await ethers.deployContract("Fundraising");
//
//         const symbol = "InvestmentToken";
//         const name = "INVT";
//         erc20Token = await ethers.deployContract("ERC20Token", [name, symbol, additionalTokens, owner.address]);
//         investmentToken = await ethers.deployContract("ERC20Token", [name, symbol, additionalTokens, owner.address]);
//         investmentToken2 = await ethers.deployContract("ERC20Token", [name, symbol, additionalTokens, owner.address]);
//         projectToken = await ethers.deployContract("ERC20Token", [name, symbol, additionalTokens, owner.address]);
//
//         forcefiPackage = await ethers.deployContract("ForcefiPackage", [mockedLzAddress]);
//         await equityFundraising.setForcefiPackageAddress(forcefiPackage.getAddress());
//
//         // Setup staking contract, add 1 investor who will receive fees
//         const forcefiToken = await ethers.deployContract("ERC20Token", [name, symbol, additionalTokens, owner.address]);
//         const forcefiStaking = await ethers.deployContract("ForcefiStaking", [mockedLzAddress, mockedLzAddress, forcefiToken.getAddress(), equityFundraising.getAddress(), mockedLzAddress]);
//
//         await forcefiStaking.setInvestorTreshholdAmount(investorTreshhold);
//         await forcefiToken.approve(forcefiStaking.getAddress(), investorTreshhold);
//         await forcefiStaking.stake(investorTreshhold, 0);
//         await forcefiStaking.setMinStakingAmount(minStakingAmount);
//
//         await forcefiToken.transfer(user1.address, minStakingAmount);
//         await forcefiToken.connect(user1).approve(forcefiStaking.getAddress(), minStakingAmount);
//         await forcefiStaking.connect(user1).stake(minStakingAmount, 0);
//
//         await equityFundraising.setForcefiStakingAddress(forcefiStaking.getAddress())
//
//         const _attachedERC20Address = [
//             investmentToken.getAddress(),
//             investmentToken2.getAddress()
//         ];
//
//         equityFundraising.whitelistTokenForInvestment(investmentToken.getAddress(), mockOracle.getAddress())
//         equityFundraising.whitelistTokenForInvestment(investmentToken2.getAddress(), mockOracle.getAddress())
//
//         await equityFundraising.setReferralFee(referralFee);
//
//         const captureValue = (value) => {
//             capturedValue = value
//             return true
//         }
//
//         await projectToken.approve(equityFundraising.getAddress(), campaignLimit)
//
//         await expect(equityFundraising.createFundraising(_fundraisingData, _attachedERC20Address, user1.getAddress(), projectName, projectToken.getAddress(), []))
//             .to.emit(equityFundraising, 'FundraisingCreated')
//             .withArgs(await owner.getAddress(), (arg) => captureValue(arg) && true, projectName);
//
//
//         const privateCampaignCaptureValue = (value) => {
//             privateCampaignCapturedValue = value
//             return true
//         }
//
//         await projectToken.approve(equityFundraising.getAddress(), campaignLimit)
//
//         await expect(equityFundraising.createFundraising(_privateCampaignFundraisingData, _attachedERC20Address, user1.getAddress(), projectName, projectToken.getAddress(), []))
//             .to.emit(equityFundraising, 'FundraisingCreated')
//             .withArgs(await owner.getAddress(), (arg) => privateCampaignCaptureValue(arg) && true, projectName);
//
//         const fundraisingCampaignWithAdjustedTreshholds = (value) => {
//             treshholdedCapturedValue = value
//             return true
//         }
//
//         await projectToken.approve(equityFundraising.getAddress(), campaignLimit)
//
//         await expect(equityFundraising.createFundraising(_fundraisingData, _attachedERC20Address, user1.getAddress(), projectName, projectToken.getAddress(), []))
//             .to.emit(equityFundraising, 'FundraisingCreated')
//             .withArgs(await owner.getAddress(), (arg) => fundraisingCampaignWithAdjustedTreshholds(arg) && true, projectName);
//     });
//
//     describe("create fundraising", function () {
//         it("should create new fundraising instance", async function () {
//             const fundraising = await equityFundraising.getFundraisingInstance(capturedValue);
//
//             await expect(fundraising[0]).to.equal(owner.address);
//             await expect(fundraising[1]).to.equal(0);
//             await expect(fundraising[2]).to.equal(_fundraisingData._isPrivate);
//             await expect(fundraising[3]).to.equal(await startDateTimestamp);
//             await expect(fundraising[4]).to.equal(await _fundraisingData._endDate);
//             await expect(fundraising[5]).to.equal(_fundraisingData._totalCampaignLimit);
//             await expect(fundraising[6]).to.equal(_fundraisingData._rate);
//             await expect(fundraising[7]).to.equal(_fundraisingData._rateDelimiter);
//             await expect(fundraising[8]).to.equal(_fundraisingData._campaignMinTicketLimit);
//             await expect(fundraising[9]).to.equal(false);
//             await expect(fundraising[10]).to.equal(await projectToken.getAddress());
//             await expect(fundraising[11]).to.equal(await user1.getAddress());
//             await expect(fundraising[12]).to.equal(referralFee);
//             await expect(fundraising[13]).to.equal(projectName);
//             await expect(fundraising[14]).to.equal(_fundraisingData._campaignMaxTicketLimit);
//
//             await expect(await projectToken.balanceOf(equityFundraising)).to.equal(_fundraisingData._totalCampaignLimit + _privateCampaignFundraisingData._totalCampaignLimit + _fundraisingData._totalCampaignLimit);
//         });
//
//         it("should invest in new fundraising", async function () {
//
//             const investorBalance = 1000;
//             const investmentAmount = minStakingAmount;
//
//             await investmentToken.transfer(user1.address, investorBalance);
//             let investmentAmountConverted = Number(investmentAmount) * Number(await equityFundraising.getChainlinkDataFeedLatestAnswer(investmentToken));
//
//             await investmentToken.connect(user1).approve(equityFundraising, investmentAmountConverted);
//             await equityFundraising.connect(user1).invest(investmentAmount, investmentToken, capturedValue);
//
//             await expect(await equityFundraising.individualBalances(capturedValue, user1.address, investmentToken)).to.equal(investmentAmount)
//
//             await expect(await investmentToken.balanceOf(user1.address)).to.equal(investorBalance - investmentAmountConverted)
//
//             const individualBalance = await equityFundraising.individualBalances(capturedValue, user1)
//             await expect(individualBalance).to.equal(investmentAmount)
//
//             const individualInvestmentTokenBalance = await equityFundraising.connect(user1).getIndividualBalanceForToken(capturedValue, investmentToken)
//
//             await expect(individualInvestmentTokenBalance).to.equal(investmentAmountConverted)
//
//             const fundraising = await equityFundraising.getFundraisingInstance(capturedValue);
//             await expect(fundraising[1]).to.equal(investmentAmount);
//
//             const fundraisingBalanceInInvestmentTokens = await equityFundraising.fundraisingBalance(capturedValue, investmentToken)
//             await expect(fundraisingBalanceInInvestmentTokens).to.equal(investmentAmountConverted);
//         });
//
//         it('should prevent investing more than limit', async function () {
//             await investmentToken.approve(equityFundraising, _fundraisingData._campaignMaxTicketLimit);
//             const investmentAmount = 250;
//             let investmentAmountConverted = Number(_fundraisingData._totalCampaignLimit) * Number(await equityFundraising.getChainlinkDataFeedLatestAnswer(investmentToken));
//
//             await investmentToken.approve(equityFundraising, investmentAmountConverted);
//             await equityFundraising.invest(investmentAmount, investmentToken, capturedValue)
//
//             await investmentToken.transfer(user1.address, investmentAmountConverted);
//             await investmentToken.connect(user1).approve(equityFundraising, _fundraisingData._totalCampaignLimit);
//             await expect(equityFundraising.connect(user1).invest(_fundraisingData._campaignMaxTicketLimit + 1, investmentToken, capturedValue)).to.be.revertedWith("Amount should be less than campaign max ticket limit");
//
//             await expect(equityFundraising.connect(user1).invest(_fundraisingData._campaignMaxTicketLimit, investmentToken, capturedValue)).to.be.revertedWith("Campaign has reached its total fund raised required");
//
//         });
//
//         it('should invest with multiple currencies, but prevent investing more than limit', async function () {
//             await investmentToken.approve(equityFundraising, _fundraisingData._campaignMaxTicketLimit);
//             const investmentAmount = 100;
//             let investmentAmountConverted = Number(investmentAmount) * Number(await equityFundraising.getChainlinkDataFeedLatestAnswer(investmentToken));
//
//             await investmentToken.approve(equityFundraising, investmentAmountConverted);
//             await equityFundraising.invest(investmentAmount, investmentToken, capturedValue)
//
//             await expect(await investmentToken.balanceOf(equityFundraising)).to.equal(investmentAmountConverted);
//             await expect(await investmentToken.balanceOf(owner)).to.equal(additionalTokens - investmentAmountConverted);
//
//             await investmentToken2.approve(equityFundraising, investmentAmountConverted);
//             await equityFundraising.invest(investmentAmount, investmentToken2, capturedValue)
//
//             await expect(await investmentToken2.balanceOf(equityFundraising)).to.equal(investmentAmountConverted);
//             await expect(await investmentToken2.balanceOf(owner)).to.equal(additionalTokens - investmentAmountConverted);
//
//             const individualInvestmentTokenBalance = await equityFundraising.getIndividualBalanceForToken(capturedValue, investmentToken)
//             await expect(individualInvestmentTokenBalance).to.equal(investmentAmountConverted)
//
//             const individualInvestmentTokenBalance2 = await equityFundraising.getIndividualBalanceForToken(capturedValue, investmentToken2)
//             await expect(individualInvestmentTokenBalance2).to.equal(investmentAmountConverted)
//
//             const individualBalance = await equityFundraising.individualBalances(capturedValue, owner)
//             await expect(individualBalance).to.equal(investmentAmount * 2)
//         });
//
//         it('should invest with less than min ticket limit if campaign almost reached its goal', async function () {
//             const investmentAmount = 295;
//             let investmentAmountConverted = Number(investmentAmount) * Number(await equityFundraising.getChainlinkDataFeedLatestAnswer(investmentToken));
//
//             await investmentToken.approve(equityFundraising, investmentAmountConverted);
//             await equityFundraising.invest(investmentAmount, investmentToken, capturedValue)
//
//             await expect(await investmentToken.balanceOf(equityFundraising)).to.equal(investmentAmountConverted);
//             await expect(await investmentToken.balanceOf(owner)).to.equal(additionalTokens - investmentAmountConverted);
//
//             const individualInvestmentTokenBalance = await equityFundraising.getIndividualBalanceForToken(capturedValue, investmentToken)
//             await expect(individualInvestmentTokenBalance).to.equal(investmentAmountConverted)
//
//             const investmentAmountLessThanLimit = 5;
//             let investmentAmountConvertedLessThanLimit = Number(investmentAmountLessThanLimit) * Number(await equityFundraising.getChainlinkDataFeedLatestAnswer(investmentToken));
//
//             await investmentToken.approve(equityFundraising, investmentAmountConvertedLessThanLimit);
//             await equityFundraising.invest(investmentAmountLessThanLimit, investmentToken, capturedValue)
//
//             await expect(await investmentToken.balanceOf(equityFundraising)).to.equal(investmentAmountConverted + investmentAmountConvertedLessThanLimit);
//             await expect(await investmentToken.balanceOf(owner)).to.equal(additionalTokens - investmentAmountConverted - investmentAmountConvertedLessThanLimit);
//
//             const individualInvestmentTokenBalanceAfterSecondInvest = await equityFundraising.getIndividualBalanceForToken(capturedValue, investmentToken)
//             await expect(individualInvestmentTokenBalanceAfterSecondInvest).to.equal(investmentAmountConverted + investmentAmountConvertedLessThanLimit)
//         });
//
//         it('should prevent investing less than minimal amount', async function () {
//             await expect(equityFundraising.connect(user1).invest(_fundraisingData._campaignMinTicketLimit - 1, investmentToken, capturedValue)).to.be.revertedWith("Amount should be more than campaign min ticket limit");
//         });
//
//         it('should prevent investing if not whitelisted address', async function () {
//             const investmentAmount = 150;
//             let investmentAmountConverted = Number(investmentAmount) * Number(await equityFundraising.getChainlinkDataFeedLatestAnswer(investmentToken)) * _privateCampaignFundraisingData._rate / _privateCampaignFundraisingData._rateDelimiter;
//             await investmentToken.approve(equityFundraising, investmentAmountConverted);
//
//             const whitelistAddress = [owner.address]
//             await expect(equityFundraising.connect(user1).invest(investmentAmount, investmentToken, privateCampaignCapturedValue)).to.be.revertedWith("not whitelisted address");
//
//             await equityFundraising.addWhitelistAddress(whitelistAddress, privateCampaignCapturedValue);
//
//             await equityFundraising.invest(investmentAmount, investmentToken, privateCampaignCapturedValue);
//
//             const individualBalance = await equityFundraising.individualBalances(privateCampaignCapturedValue, owner)
//             await expect(individualBalance).to.equal(investmentAmount)
//
//             const individualInvestmentTokenBalance = await equityFundraising.getIndividualBalanceForToken(privateCampaignCapturedValue, investmentToken)
//
//             await expect(individualInvestmentTokenBalance).to.equal(investmentAmountConverted)
//         });
//
//         it("should close campaign with adjusted fees and margins", async function () {
//             const tier2TreshholdPercentage = 7;
//             await investmentToken.approve(equityFundraising, _fundraisingData._campaignMaxTicketLimit);
//             const investmentAmount = _fundraisingData._campaignMaxTicketLimit;
//             let investmentAmountConverted = Number(investmentAmount) * Number(await equityFundraising.getChainlinkDataFeedLatestAnswer(investmentToken));
//
//             await investmentToken.approve(equityFundraising, investmentAmountConverted);
//             await equityFundraising.invest(investmentAmount, investmentToken, treshholdedCapturedValue)
//
//             await equityFundraising.setSuccessfulFundraisingFeeAddress(user2.address)
//             await equityFundraising.setCuratorsContractAddress(user4.address)
//
//             await expect(await projectToken.balanceOf(equityFundraising)).to.equal(_fundraisingData._totalCampaignLimit + _privateCampaignFundraisingData._totalCampaignLimit + _fundraisingData._totalCampaignLimit);
//             await expect(await investmentToken.balanceOf(owner)).to.equal(additionalTokens - investmentAmountConverted);
//
//             const reclaimWindow = 0;
//             const campaignMinThreshold = 30;
//             await equityFundraising.setFeeConfig(250, 1000, 5, tier2TreshholdPercentage, 10, reclaimWindow, campaignMinThreshold)
//
//             await equityFundraising.closeCampaign(treshholdedCapturedValue);
//
//             await expect(equityFundraising.closeCampaign(treshholdedCapturedValue)).to.be.revertedWith("Campaign already closed");
//
//             // Compare balances after closing campaign
//             await expect(await projectToken.balanceOf(equityFundraising)).to.equal(investmentAmount + _privateCampaignFundraisingData._totalCampaignLimit + _fundraisingData._totalCampaignLimit);
//             await expect(await projectToken.balanceOf(owner)).to.equal(additionalTokens - investmentAmount - _privateCampaignFundraisingData._totalCampaignLimit - _fundraisingData._totalCampaignLimit);
//
//             const successfulFundraisingFeeAmount = investmentAmountConverted * tier2TreshholdPercentage / 100;
//             const referralFeeInWei = investmentAmountConverted * referralFee / 100;
//             await expect(await investmentToken.balanceOf(owner)).to.equal(additionalTokens - successfulFundraisingFeeAmount - referralFeeInWei);
//             await expect(await investmentToken.balanceOf(user2)).to.equal(Math.floor(successfulFundraisingFeeAmount / 5));
//             await expect(await investmentToken.balanceOf(user1)).to.equal(referralFeeInWei);
//         });
//
//         it("should close campaign when reached cap", async function () {
//             await investmentToken.approve(equityFundraising, _fundraisingData._campaignMaxTicketLimit);
//             const investmentAmount = _fundraisingData._campaignMaxTicketLimit;
//             let investmentAmountConverted = Number(investmentAmount) * Number(await equityFundraising.getChainlinkDataFeedLatestAnswer(investmentToken));
//
//             await investmentToken.approve(equityFundraising, investmentAmountConverted);
//             await equityFundraising.invest(investmentAmount, investmentToken, capturedValue)
//
//             await equityFundraising.setSuccessfulFundraisingFeeAddress(user2.address)
//             await equityFundraising.setCuratorsContractAddress(user4.address)
//
//             await expect(await projectToken.balanceOf(equityFundraising)).to.equal(_fundraisingData._totalCampaignLimit + _privateCampaignFundraisingData._totalCampaignLimit + _fundraisingData._totalCampaignLimit);
//             await expect(await investmentToken.balanceOf(owner)).to.equal(additionalTokens - investmentAmountConverted);
//
//             await equityFundraising.closeCampaign(capturedValue);
//
//             await expect(equityFundraising.closeCampaign(capturedValue)).to.be.revertedWith("Campaign already closed");
//
//             // Compare balances after closing campaign
//             await expect(await projectToken.balanceOf(equityFundraising)).to.equal(investmentAmount + _privateCampaignFundraisingData._totalCampaignLimit + _fundraisingData._totalCampaignLimit);
//             await expect(await projectToken.balanceOf(owner)).to.equal(additionalTokens - investmentAmount - _privateCampaignFundraisingData._totalCampaignLimit - _fundraisingData._totalCampaignLimit);
//
//             const successfulFundraisingFeeAmount = investmentAmountConverted * 5 / 100;
//             const referralFeeInWei = investmentAmountConverted * referralFee / 100;
//             await expect(await investmentToken.balanceOf(owner)).to.equal(additionalTokens - successfulFundraisingFeeAmount - referralFeeInWei);
//             await expect(await investmentToken.balanceOf(user2)).to.equal(Math.floor(successfulFundraisingFeeAmount / 5));
//             await expect(await investmentToken.balanceOf(user1)).to.equal(referralFeeInWei);
//
//             await expect(await equityFundraising.released(capturedValue, owner.address)).to.equal(0)
//             // Claim Tokens as investor
//             await ethers.provider.send('evm_increaseTime', [await _fundraisingData._endDate - await _fundraisingData._startDate + 1]);
//             await ethers.provider.send('evm_mine');
//             await equityFundraising.claimTokens(capturedValue);
//
//             await expect(await equityFundraising.released(capturedValue, owner.address)).to.equal(investmentAmount)
//         });
//
//         it("should reclaim tokens when campaign failed to raise funds", async function () {
//
//             const newEndDate = await endDate + 1000
//             const _newFundraisingData = {
//                 _label: "simple vesting",
//                 _vestingStart: 0,
//                 _cliffPeriod: 0,
//                 _vestingPeriod: 0,
//                 _releasePeriod: 0,
//                 _tgePercent: 0,
//                 _totalCampaignLimit: campaignLimit,
//                 _campaignSoftCap: 250,
//                 _rate: 100,
//                 _rateDelimiter: 100,
//                 _startDate: startDateTimestamp,
//                 _endDate: newEndDate,
//                 _isPrivate: false,
//                 _campaignMinTicketLimit: 100,
//                 _campaignMaxTicketLimit: 300
//             }
//
//             const _attachedERC20Address = [
//                 investmentToken.getAddress(),
//                 investmentToken2.getAddress()
//             ];
//
//             const newEquityFundraising = (value) => {
//                 newFundraisingCampaign = value
//                 return true
//             }
//
//             await projectToken.approve(equityFundraising.getAddress(), campaignLimit)
//
//             await expect(equityFundraising.createFundraising(_newFundraisingData, _attachedERC20Address, user1.getAddress(), projectName, projectToken.getAddress(), []))
//                 .to.emit(equityFundraising, 'FundraisingCreated')
//                 .withArgs(await owner.getAddress(), (arg) => newEquityFundraising(arg) && true, projectName);
//
//             await investmentToken.approve(equityFundraising, _newFundraisingData._campaignMaxTicketLimit);
//             const investmentAmount = _newFundraisingData._campaignMinTicketLimit;
//             let investmentAmountConverted = Number(investmentAmount) * Number(await equityFundraising.getChainlinkDataFeedLatestAnswer(investmentToken));
//
//             await investmentToken.approve(equityFundraising, investmentAmountConverted);
//             await equityFundraising.invest(investmentAmount, investmentToken, newFundraisingCampaign);
//
//             await investmentToken2.approve(equityFundraising, investmentAmountConverted);
//             await equityFundraising.invest(investmentAmount, investmentToken2, newFundraisingCampaign);
//
//             await expect(await projectToken.balanceOf(equityFundraising)).to.equal(_fundraisingData._totalCampaignLimit + _privateCampaignFundraisingData._totalCampaignLimit + _fundraisingData._totalCampaignLimit + _newFundraisingData._totalCampaignLimit);
//             await expect(await investmentToken.balanceOf(owner)).to.equal(additionalTokens - investmentAmountConverted);
//             await expect(await investmentToken2.balanceOf(owner)).to.equal(additionalTokens - investmentAmountConverted);
//
//             await expect(equityFundraising.closeCampaign(newFundraisingCampaign)).to.be.revertedWith("Campaign is not yet ended or didn't reach minimal threshold");
//
//             await expect(equityFundraising.reclaimTokens(newFundraisingCampaign)).to.be.revertedWith("Campaign has not ended");
//
//             // Increase time
//             await ethers.provider.send('evm_increaseTime', [await _newFundraisingData._endDate - await _newFundraisingData._startDate + 1]);
//             await ethers.provider.send('evm_mine');
//
//             await equityFundraising.reclaimTokens(newFundraisingCampaign);
//
//             await expect(await investmentToken.balanceOf(owner)).to.equal(additionalTokens);
//             await expect(await investmentToken.balanceOf(equityFundraising)).to.equal(0);
//
//             await expect(await investmentToken2.balanceOf(owner)).to.equal(additionalTokens);
//             await expect(await investmentToken2.balanceOf(equityFundraising)).to.equal(0);
//         });
//
//         it('set fee amount and test fundraising creation', async function () {
//             const feeAmount = 500;
//             await equityFundraising.setFeeAmount(feeAmount);
//
//             const _attachedERC20Address = [
//                 investmentToken.getAddress()
//             ];
//
//             await projectToken.approve(equityFundraising.getAddress(), campaignLimit)
//
//             const captureValue = (value) => {
//                 capturedValue = value
//                 return true
//             }
//
//             await expect(equityFundraising.createFundraising(_fundraisingData, _attachedERC20Address, user1.getAddress(), projectName, projectToken.getAddress(), [],
//                 { value: feeAmount }))
//                 .to.emit(equityFundraising, 'FundraisingCreated')
//                 .withArgs(await owner.getAddress(), (arg) => captureValue(arg) && true, projectName);
//
//             const contractBalanceAfterFundraisingCreation = await ethers.provider.getBalance(equityFundraising.getAddress());
//             await expect(contractBalanceAfterFundraisingCreation).to.equal(feeAmount);
//
//             // Withdraw fee
//             const treasuryWallet = ethers.Wallet.createRandom();
//             await expect(await ethers.provider.getBalance(treasuryWallet.address)).to.equal(0);
//
//             await expect(equityFundraising.connect(user1).withdrawFee(treasuryWallet.address)).to.be.revertedWithCustomError(equityFundraising, "OwnableUnauthorizedAccount");
//             await equityFundraising.withdrawFee(treasuryWallet.address);
//
//             const finalBalance = await ethers.provider.getBalance(equityFundraising.getAddress());
//             await expect(finalBalance).to.equal(0);
//             await expect(await ethers.provider.getBalance(treasuryWallet.address)).to.equal(feeAmount);
//         });
//
//         it('set forcefi package address and create fundraising when has creation token ', async function () {
//             const feeAmount = 500;
//             await equityFundraising.setFeeAmount(feeAmount);
//
//             const _attachedERC20Address = [
//                 investmentToken.getAddress()
//             ];
//
//             await projectToken.approve(equityFundraising.getAddress(), campaignLimit)
//
//             const captureValue = (value) => {
//                 capturedValue = value
//                 return true
//             }
//
//             const MockOracle = await ethers.getContractFactory("MockV3Aggregator");
//             const mockOracle = await MockOracle.deploy(
//                 "18",
//                 "1000"
//             );
//             await forcefiPackage.whitelistTokenForInvestment(erc20Token.getAddress(), mockOracle.getAddress());
//
//             const _acceleratorPackageLabel = "Accelerator";
//             const packageTotalPrice = 2000;
//             const erc20TokenPrice = await forcefiPackage.getChainlinkDataFeedLatestAnswer(erc20Token.getAddress());
//             const totalTokensPerPackage = packageTotalPrice * Number(erc20TokenPrice);
//             await erc20Token.approve(forcefiPackage.getAddress(), totalTokensPerPackage.toString());
//
//             await forcefiPackage.buyPackage(projectName, _acceleratorPackageLabel, erc20Token.getAddress(), owner.address);
//             expect(await forcefiPackage.hasCreationToken(owner, projectName)).to.equal(true);
//
//             await expect(equityFundraising.createFundraising(_fundraisingData, _attachedERC20Address, user1.getAddress(), projectName, projectToken.getAddress(), []))
//                 .to.emit(equityFundraising, 'FundraisingCreated')
//                 .withArgs(await owner.getAddress(), (arg) => captureValue(arg) && true, projectName);
//         });
//
//     });
//
// });
