// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./ForcefiBaseContract.sol";
import "./VestingLibrary.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

interface IForcefiStaking {
    function hasAddressStaked(address) external view returns(bool);
    function receiveFees(address, uint) external;
}

/**
 * @title Fundraising
 * @dev This contract is used for creating and managing fundraising campaigns with vesting plans.
 */
contract Fundraising is ForcefiBaseContract{
    uint256 private _fundraisingIdCounter;

    mapping(address => AggregatorV3Interface) dataFeeds;

    uint public referralFee;
    address public successfulFundraiseFeeAddress;
    address public forcefiStakingAddress;
    address public curatorContractAddress;
    FeeConfig public feeConfig;

    mapping(bytes32 => FundraisingInstance) fundraisings;
    mapping(bytes32 => address []) whitelistedTokens;
    mapping(bytes32 => mapping(address => bool)) whitelistedAddresses;
    mapping(bytes32 => mapping(address => uint)) public fundraisingBalance;

    // Amount of tokens released for investor
    mapping(bytes32 => mapping(address => uint)) public released;
    mapping(bytes32 => mapping(address => bool)) whitelistedToken;
    mapping(bytes32 => VestingPlan) vestingPlans;
    mapping(address => bool) public isInvestmentToken;

    mapping(bytes32 => mapping(address => IndividualBalances)) public individualBalances;

    /**
     * @dev Struct to track individual balances within a fundraising campaign.
     * @param investmentTokenBalances A mapping of token addresses to their corresponding balances.
     * @param fundraisingTokenBalance The balance of fundraising tokens held by the individual.
     */
    struct IndividualBalances {
        mapping(address => uint) investmentTokenBalances;
        uint fundraisingTokenBalance;
    }

    /**
     * @dev Struct to define a vesting plan.
     * @param label The label or name of the vesting plan.
     * @param saleStart The timestamp when the vesting period starts.
     * @param cliffPeriod The duration of the cliff period (in seconds) before tokens start vesting.
     * @param vestingPeriod The total duration of the vesting period (in seconds).
     * @param releasePeriod The period (in seconds) how often tokens are released after the cliff period.
     * @param tgePercent The percentage of tokens released at the Token Generation Event (TGE).
     * @param totalTokenAmount The total amount of tokens allocated for this fundraising.
     */
    struct VestingPlan {
        string label;
        uint saleStart;
        uint cliffPeriod;
        uint vestingPeriod;
        uint releasePeriod;
        uint tgePercent;
        uint totalTokenAmount;
    }

    /**
     * @dev Struct to define the data required to create a new fundraising campaign.
     * @param _label The label or name of the fundraising campaign.
     * @param _vestingStart The timestamp when the vesting period starts.
     * @param _cliffPeriod The duration of the cliff period (in seconds) before tokens start vesting.
     * @param _vestingPeriod The total duration of the vesting period (in seconds).
     * @param _releasePeriod The period (in seconds) how often tokens are released after the cliff period.
     * @param _tgePercent The percentage of tokens released at the Token Generation Event (TGE).
     * @param _totalCampaignLimit The maximum amount of tokens that can be raised during the campaign.
     * @param _rate The exchange rate between the investment token and the fundraising token.
     * @param _rateDelimiter The denominator used in calculating the exchange rate.
     * @param _startDate The timestamp when the fundraising campaign starts.
     * @param _endDate The timestamp when the fundraising campaign ends.
     * @param _isPrivate Whether the campaign is private or public.
     * @param _campaignMinTicketLimit The minimum amount required to participate in the campaign.
     * @param _campaignMaxTicketLimit The maximum amount that can be contributed by a single participant.
     */
    struct FundraisingData {
        string _label;
        uint _vestingStart;
        uint _cliffPeriod;
        uint _vestingPeriod;
        uint _releasePeriod;
        uint _tgePercent;
        uint _totalCampaignLimit;
        uint _rate;
        uint _rateDelimiter;
        uint _startDate;
        uint _endDate;
        bool _isPrivate;
        uint _campaignMinTicketLimit;
        uint _campaignMaxTicketLimit;
    }

    /**
     * @dev Struct to store details of an individual fundraising campaign.
     * @param owner The address of the campaign owner.
     * @param totalFundraised The total amount raised during the campaign.
     * @param privateFundraising Indicates if the campaign is private.
     * @param startDate The start date of the campaign.
     * @param endDate The end date of the campaign.
     * @param campaignHardCap The maximum amount of funds the campaign can raise.
     * @param rate The exchange rate between the investment token and the fundraising token.
     * @param rateDelimiter The denominator used in calculating the exchange rate.
     * @param campaignMinTicketLimit The minimum contribution required to participate.
     * @param campaignClosed Indicates if the campaign is closed.
     * @param mintingErc20TokenAddress The address of the ERC20 token being minted for the campaign.
     * @param referralAddress The address to which referral fees are sent.
     * @param fundraisingReferralFee The percentage of funds allocated as a referral fee.
     * @param projectName The name of the project associated with the campaign.
     * @param campaignMaxTicketLimit The maximum amount that can be contributed by a single participant.
     */
    struct FundraisingInstance {
        address owner;
        uint totalFundraised;
        bool privateFundraising;

        uint startDate;
        uint endDate;
        uint campaignHardCap;
        uint rate;
        uint rateDelimiter;
        uint campaignMinTicketLimit;

        bool campaignClosed;
        address mintingErc20TokenAddress;
        address referralAddress;
        uint fundraisingReferralFee;
        string projectName;
        uint campaignMaxTicketLimit;
        FeeConfig fundraisingFeeConfig;
    }

    /**
     * @dev Struct to configure fee settings for fundraising campaigns.
     * @param tier1Threshold The fundraising amount threshold for tier 1 fees.
     * @param tier2Threshold The fundraising amount threshold for tier 2 fees.
     * @param tier1FeePercentage The percentage fee applied for tier 1.
     * @param tier2FeePercentage The percentage fee applied for tier 2.
     * @param tier3FeePercentage The percentage fee applied for tier 3.
     * @param reclaimWindow The time window (in seconds) for reclaiming funds.
     * @param minCampaignThreshold The minimum threshold percentage of the campaign hard cap that must be met for a successful campaign.
     */
    struct FeeConfig {
        uint256 tier1Threshold;
        uint256 tier2Threshold;
        uint256 tier1FeePercentage;
        uint256 tier2FeePercentage;
        uint256 tier3FeePercentage;
        uint256 reclaimWindow;
        uint256 minCampaignThreshold;
    }

    event CampaignClosed(address indexed, uint, bytes32);
    event TokensClaimed(address indexed, uint);
    event TokensReclaimed(address indexed, address, uint);
    event FundraisingCreated(address indexed ownerAddress, bytes32, string);
    event Invested(address indexed investor, uint amount, address sentTokenAddress, address fundraisingAddress);
    event WhitelistedAddress(address whitelistedAddress);
    event ReferralFeeSent(address indexed whitelistedAddress, address erc20TokenAddress, string, uint);

    modifier isFundraisingOwner(bytes32 _fundraisingIdx){
        FundraisingInstance storage fundraising = fundraisings[_fundraisingIdx];
        require(fundraising.owner == msg.sender, "Not an owner of a fundraising");
        _;
    }

    constructor() {
        feeConfig = FeeConfig({
            tier1Threshold: 1_000_000 * 1e18,
            tier2Threshold: 2_500_000 * 1e18,
            tier1FeePercentage: 5,
            tier2FeePercentage: 4,
            tier3FeePercentage: 3,
            reclaimWindow: 0,
            minCampaignThreshold: 70
        });
    }

    /**
     * @dev Creates a new fundraising campaign. Campaign can be created either if the owner of the @param _projectName has creation token in ForcefiPackage contract or pays the fee.
     * @param _fundraisingData The data required to create the fundraising campaign.
     * @param _attachedERC20Address The addresses of the ERC20 tokens accepted for investment.
     * @param _referralAddress The address for receiving referral fees.
     * @param _projectName The name of the project.
     * @param _fundraisingErc20TokenAddress The address of the ERC20 token being locked.
     * @param _whitelistAddresses The addresses to whitelist for private campaigns.
     */
    function createFundraising(FundraisingData memory _fundraisingData, address [] memory _attachedERC20Address, address _referralAddress, string memory _projectName, address _fundraisingErc20TokenAddress, address [] calldata _whitelistAddresses) external payable {
        bool hasCreationToken = IForcefiPackage(forcefiPackageAddress).hasCreationToken(msg.sender, _projectName);
        require(msg.value == feeAmount || hasCreationToken, "Invalid fee value or no creation token available");
        ERC20(_fundraisingErc20TokenAddress).transferFrom(msg.sender, address(this), _fundraisingData._totalCampaignLimit);

        FundraisingInstance memory fundraising;
        fundraising.owner = msg.sender;
        fundraising.campaignHardCap = _fundraisingData._totalCampaignLimit;
        fundraising.rate = _fundraisingData._rate;
        fundraising.rateDelimiter = _fundraisingData._rateDelimiter;
        fundraising.privateFundraising = _fundraisingData._isPrivate;
        fundraising.startDate = _fundraisingData._startDate;
        fundraising.endDate = _fundraisingData._endDate;
        fundraising.campaignMinTicketLimit = _fundraisingData._campaignMinTicketLimit;
        fundraising.referralAddress = _referralAddress;
        fundraising.fundraisingReferralFee = referralFee;
        fundraising.projectName = _projectName;
        fundraising.mintingErc20TokenAddress = _fundraisingErc20TokenAddress;
        fundraising.campaignMaxTicketLimit = _fundraisingData._campaignMaxTicketLimit;
        fundraising.fundraisingFeeConfig = FeeConfig({
            tier1Threshold: feeConfig.tier1Threshold,
            tier2Threshold: feeConfig.tier2Threshold,
            tier1FeePercentage: feeConfig.tier1FeePercentage,
            tier2FeePercentage: feeConfig.tier2FeePercentage,
            tier3FeePercentage: feeConfig.tier3FeePercentage,
            reclaimWindow: feeConfig.reclaimWindow,
            minCampaignThreshold: feeConfig.minCampaignThreshold
        });

        uint fundraisingIdx = _fundraisingIdCounter;
        _fundraisingIdCounter += 1;

        bytes32 UUID = VestingLibrary.generateUUID(fundraisingIdx);
        address [] storage tokensToPush = whitelistedTokens[UUID];
        for (uint i=0; i< _attachedERC20Address.length; i++){
            require(isInvestmentToken[_attachedERC20Address[i]], "Not whitelisted investment token address");
            tokensToPush.push(_attachedERC20Address[i]);
            whitelistedToken[UUID][_attachedERC20Address[i]] = true;
        }
        whitelistedTokens[UUID] = tokensToPush;

        vestingPlans[UUID] = VestingPlan(_fundraisingData._label,
            _fundraisingData._vestingStart,
            _fundraisingData._cliffPeriod,
            _fundraisingData._vestingPeriod,
            _fundraisingData._releasePeriod,
            _fundraisingData._tgePercent,
            _fundraisingData._totalCampaignLimit);

        fundraisings[UUID] = fundraising;

        if(_fundraisingData._isPrivate){
            addWhitelistAddress(_whitelistAddresses, UUID);
        }

        emit FundraisingCreated(msg.sender, UUID, _projectName);
    }

    function getIndividualBalanceForToken(bytes32 _idx, address _investmentTokenAddress) public view returns(uint){
        return individualBalances[_idx][msg.sender].investmentTokenBalances[_investmentTokenAddress];
    }

    function getFundraisingInstance(bytes32 _idx) public view returns (FundraisingInstance memory){
        return fundraisings[_idx];
    }

    function getVestingPlan(bytes32 _idx) public view returns (VestingPlan memory){
        return vestingPlans[_idx];
    }

    function getWhitelistedTokens(bytes32 _idx) public view returns(address[] memory){
        return whitelistedTokens[_idx];
    }

    function setSuccessfulFundraisingFeeAddress(address _successfulFundraiseFeeAddress) external onlyOwner {
        successfulFundraiseFeeAddress = _successfulFundraiseFeeAddress;
    }

    function addWhitelistAddress(address [] calldata _whitelistAddress, bytes32 _fundraisingIdx) public isFundraisingOwner(_fundraisingIdx) {
        for(uint i = 0; i< _whitelistAddress.length; i++){
            whitelistedAddresses[_fundraisingIdx][_whitelistAddress[i]] = true;
            emit WhitelistedAddress(_whitelistAddress[i]);
        }
    }

    // Function to update the fee configuration
    function setFeeConfig(uint256 _tier1Threshold, uint256 _tier2Threshold, uint256 _tier1FeePercentage, uint256 _tier2FeePercentage, uint256 _tier3FeePercentage, uint256 _reclaimWindow, uint256 _minCampaignThreshold) external onlyOwner {
        feeConfig = FeeConfig({
            tier1Threshold: _tier1Threshold,
            tier2Threshold: _tier2Threshold,
            tier1FeePercentage: _tier1FeePercentage,
            tier2FeePercentage: _tier2FeePercentage,
            tier3FeePercentage: _tier3FeePercentage,
            reclaimWindow: _reclaimWindow,
            minCampaignThreshold: _minCampaignThreshold
        });
    }

    /**
     * @dev Invests in a fundraising campaign. Campaign has to be still active. To participate in the sale, users must stake a sufficient amount of FORC tokens.
     * @param _amount The amount of tokens to invest, it has to be larger than campaignMinTicketLimit and less than campaignMaxTicketLimit for all investments combined.
              When campaign has almost reached its cap, amount can be less than campaignMinTicketLimit
     * @param _fundraisingIdx The ID of the campaign to invest in.
     * @param _whitelistedTokenAddress The address of the token being sent for the investment. It has to be whitelisted for the particular sale
     */
    function invest(uint256 _amount, address _whitelistedTokenAddress, bytes32 _fundraisingIdx) external {
        FundraisingInstance storage fundraising = fundraisings[_fundraisingIdx];
        require(_amount >= fundraising.campaignMinTicketLimit || fundraising.campaignHardCap - fundraising.totalFundraised <= fundraising.campaignMinTicketLimit, "Amount should be more than campaign min ticket limit");
        require(individualBalances[_fundraisingIdx][msg.sender].fundraisingTokenBalance + _amount <= fundraising.campaignMaxTicketLimit, "Amount should be less than campaign max ticket limit");
        require(fundraising.campaignHardCap >= _amount + fundraising.totalFundraised, "Campaign has reached its total fund raised required");
        require(block.timestamp >= fundraising.startDate, "Campaign hasn't started yet");
        require(block.timestamp <= fundraising.endDate, "Campaign has ended");
        require(!fundraising.campaignClosed, "Campaign is closed");

        bool isWhitelistedToken = false;
        for(uint i=0; i< whitelistedTokens[_fundraisingIdx].length; i++){
            if(whitelistedTokens[_fundraisingIdx][i] == _whitelistedTokenAddress){
                isWhitelistedToken = true;
            }
        }
        require(isWhitelistedToken, "Only project whitelisted token can be accepted as investment");

        if(forcefiStakingAddress != address(0)){
            require(IForcefiStaking(forcefiStakingAddress).hasAddressStaked(msg.sender), "To participate in the sale, users must stake a sufficient amount of FORC tokens.");
        }

        require(isInvestmentToken[_whitelistedTokenAddress], "Not whitelisted investment token address");
        if(fundraising.privateFundraising){
            require(whitelistedAddresses[_fundraisingIdx][msg.sender], "not whitelisted address");
        }

        uint erc20Decimals = ERC20(_whitelistedTokenAddress).decimals();

        uint investTokenAmount = (getChainlinkDataFeedLatestAnswer(_whitelistedTokenAddress) * fundraising.rate * _amount ) / fundraising.rateDelimiter / 10 ** erc20Decimals;
        individualBalances[_fundraisingIdx][msg.sender].fundraisingTokenBalance += _amount;
        individualBalances[_fundraisingIdx][msg.sender].investmentTokenBalances[_whitelistedTokenAddress] += investTokenAmount;

        ERC20(_whitelistedTokenAddress).transferFrom(msg.sender, address(this), investTokenAmount);
        fundraisingBalance[_fundraisingIdx][_whitelistedTokenAddress] += investTokenAmount;

        fundraising.totalFundraised += _amount;
        emit Invested(msg.sender, _amount, _whitelistedTokenAddress, address(this));
    }

    /**
     * @dev Closes a fundraising campaign.
            To close campaign it has to reach it's minimal threshold after end date + reclaimWindow.
            This event sends investmentTokens to referralAddress(if it's attached), successFulFundraiseFeeAddress and calls forcefiStakingContract and curatorContract to receive and distribute fees.
            All other tokens are sent to the owner of the campaign.
     * @param _fundraisingIdx The ID of the campaign to close.
     */
    function closeCampaign(bytes32 _fundraisingIdx) external isFundraisingOwner(_fundraisingIdx) {
        FundraisingInstance storage fundraising = fundraisings[_fundraisingIdx];
        require(!fundraising.campaignClosed, "Campaign already closed");
        bool hasReachedLimit = fundraising.totalFundraised > fundraising.campaignHardCap * fundraising.fundraisingFeeConfig.minCampaignThreshold / 100;
        require(hasReachedLimit && fundraising.endDate + fundraising.fundraisingFeeConfig.reclaimWindow >= block.timestamp, "Campaign is not yet ended or didn't reach minimal threshold");

        fundraising.campaignClosed = true;

        uint feePercentage = calculateFee(fundraising.totalFundraised, fundraising.fundraisingFeeConfig);

        for(uint i=0; i< whitelistedTokens[_fundraisingIdx].length; i++){
            uint totalFundraisedInWei = fundraisingBalance[_fundraisingIdx][whitelistedTokens[_fundraisingIdx][i]];

            uint feeInWei = totalFundraisedInWei * feePercentage / 100;
            uint referralFeeInWei = totalFundraisedInWei * fundraising.fundraisingReferralFee / 100;

            if(fundraising.referralAddress != address(0)){
                ERC20(whitelistedTokens[_fundraisingIdx][i]).transfer(fundraising.referralAddress, referralFeeInWei);
                emit ReferralFeeSent(fundraising.referralAddress, whitelistedTokens[_fundraisingIdx][i], fundraising.projectName, referralFeeInWei);
            }

            ERC20(whitelistedTokens[_fundraisingIdx][i]).transfer(successfulFundraiseFeeAddress, feeInWei / 5);

            ERC20(whitelistedTokens[_fundraisingIdx][i]).approve(forcefiStakingAddress, feeInWei * 3 / 10 );
            IForcefiStaking(forcefiStakingAddress).receiveFees(whitelistedTokens[_fundraisingIdx][i], feeInWei * 3 / 10);

//            ERC20(whitelistedTokens[_fundraisingIdx][i]).approve(curatorContractAddress, feeInWei / 2);
//            IForcefiStaking(curatorContractAddress).receiveFees(whitelistedTokens[_fundraisingIdx][i], feeInWei / 2);
            ERC20(whitelistedTokens[_fundraisingIdx][i]).transfer(curatorContractAddress, feeInWei / 2);

            ERC20(whitelistedTokens[_fundraisingIdx][i]).transfer(msg.sender, totalFundraisedInWei - feeInWei - referralFeeInWei);
        }

        if(fundraising.campaignHardCap > fundraising.totalFundraised){
            ERC20(fundraising.mintingErc20TokenAddress).transfer(msg.sender, fundraising.campaignHardCap - fundraising.totalFundraised);
        }

        emit CampaignClosed(msg.sender, block.timestamp, _fundraisingIdx);
    }

    /** @dev This function sends back funds to fundraising owner if campaign failed. */
    function unlockFundsFromCampaign(bytes32 _fundraisingIdx) external isFundraisingOwner(_fundraisingIdx){
        FundraisingInstance storage fundraising = fundraisings[_fundraisingIdx];
        bool hasReachedLimit = fundraising.totalFundraised > fundraising.campaignHardCap * feeConfig.minCampaignThreshold / 100;
        require(!hasReachedLimit && fundraising.endDate + feeConfig.reclaimWindow >= block.timestamp, "Campaign has reachead minimal threshold");

        fundraising.campaignClosed = true;

        require(!fundraising.campaignClosed, "Campaign already closed");
        require(block.timestamp >= fundraising.endDate, "Campaign has not ended");
        ERC20(fundraising.mintingErc20TokenAddress).transfer(msg.sender, fundraising.campaignHardCap);
    }

    /**
     * @dev Allows users to claim their tokens based on the vesting params.
            Claiming is available only after fundraising has reached it's end date + reclaim window has passed and it's considered as successful - reached min campaign threshold.
     * @param _fundraisingIdx The ID of the campaign to claim tokens from.
     */
    function claimTokens(bytes32 _fundraisingIdx) external {
        FundraisingInstance storage fundraising = fundraisings[_fundraisingIdx];
        bool hasReachedLimit = fundraising.totalFundraised > fundraising.campaignHardCap * feeConfig.minCampaignThreshold / 100;

        require(hasReachedLimit && block.timestamp >= fundraising.endDate + feeConfig.reclaimWindow, "Campaign isnt closed");

        uint256 vestedAmount = computeReleasableAmount(_fundraisingIdx);
        require(vestedAmount > 0, "TokenVesting: cannot release tokens, no vested tokens");

        released[_fundraisingIdx][msg.sender] += vestedAmount;
        ERC20(fundraising.mintingErc20TokenAddress).transfer(msg.sender, vestedAmount);
        emit TokensClaimed(msg.sender, vestedAmount);
    }

    function computeReleasableAmount(bytes32 _fundraisingIdx) public view returns(uint256){
        require(vestingPlans[_fundraisingIdx].saleStart < block.timestamp, "TokenVesting: this vesting has not started yet");
        uint mintingTokenAmount = individualBalances[_fundraisingIdx][msg.sender].fundraisingTokenBalance;
        return VestingLibrary.computeReleasableAmount(vestingPlans[_fundraisingIdx].saleStart, vestingPlans[_fundraisingIdx].vestingPeriod, vestingPlans[_fundraisingIdx].releasePeriod, vestingPlans[_fundraisingIdx].cliffPeriod, vestingPlans[_fundraisingIdx].tgePercent, mintingTokenAmount, released[_fundraisingIdx][msg.sender]);
    }

    /**
    * @dev Allows users to reclaim their tokens if campaign failed to reach it's goal.
            Reclaiming is available only after fundraising has reached it's end date + reclaim window has passed.
     * @param _fundraisingIdx The ID of the campaign to claim tokens from.
     */
    function reclaimTokens(bytes32 _fundraisingIdx) external {
        FundraisingInstance storage fundraising = fundraisings[_fundraisingIdx];
        require(block.timestamp >= fundraising.endDate, "Campaign has not ended");
        bool hasReachedLimit = fundraising.totalFundraised > fundraising.campaignHardCap * feeConfig.minCampaignThreshold / 100;
        require(!hasReachedLimit || block.timestamp <= fundraising.endDate + feeConfig.reclaimWindow, "Campaign not closed");

        for(uint i=0; i< whitelistedTokens[_fundraisingIdx].length; i++){
            uint reclaimAmount = individualBalances[_fundraisingIdx][msg.sender].investmentTokenBalances[whitelistedTokens[_fundraisingIdx][i]];
            individualBalances[_fundraisingIdx][msg.sender].investmentTokenBalances[whitelistedTokens[_fundraisingIdx][i]] = 0;

            if(reclaimAmount > 0){
                ERC20(whitelistedTokens[_fundraisingIdx][i]).transfer(msg.sender, reclaimAmount);
                emit TokensReclaimed(msg.sender, whitelistedTokens[_fundraisingIdx][i], reclaimAmount);
            }
        }
        fundraising.totalFundraised -= individualBalances[_fundraisingIdx][msg.sender].fundraisingTokenBalance;
    }

    function setReferralFee(uint _referralFee) external onlyOwner {
        referralFee = _referralFee;
    }

    function setForcefiStakingAddress(address _forcefiStakingAddress) external onlyOwner {
        forcefiStakingAddress = _forcefiStakingAddress;
    }

    function setCuratorsContractAddress(address _curatorContractAddress) external onlyOwner {
        curatorContractAddress = _curatorContractAddress;
    }

    function whitelistTokenForInvestment(address _investmentTokenAddress, address _dataFeedAddress) external onlyOwner {
        isInvestmentToken[_investmentTokenAddress] = true;
        dataFeeds[_investmentTokenAddress] = AggregatorV3Interface(_dataFeedAddress);
    }

    function getChainlinkDataFeedLatestAnswer(address _erc20TokenAddress) public view returns (uint256) {
        AggregatorV3Interface dataFeed = dataFeeds[_erc20TokenAddress];

        (
        /* uint80 roundID */,
            int answer,
        /*uint startedAt*/,
        /*uint timeStamp*/,
        /*uint80 answeredInRound*/
        ) = dataFeed.latestRoundData();

        uint erc20Decimals = ERC20(_erc20TokenAddress).decimals();

        uint256 decimals = uint256(dataFeed.decimals());
        uint256 chainlinkPrice = uint256(answer);

        if(erc20Decimals > decimals){
            return chainlinkPrice * (10 ** (erc20Decimals - decimals));
        } else if(decimals > erc20Decimals ) {
            return chainlinkPrice / (10 ** (decimals - erc20Decimals));
        } else return chainlinkPrice;
    }

    function calculateFee(uint256 amountRaised, FeeConfig memory fundraisingFeeConfig) public pure returns (uint256) {
        uint256 feePercentage;

        if (amountRaised < fundraisingFeeConfig.tier1Threshold) {
            feePercentage = fundraisingFeeConfig.tier1FeePercentage;
        } else if (amountRaised <= fundraisingFeeConfig.tier2Threshold) {
            feePercentage = fundraisingFeeConfig.tier2FeePercentage;
        } else {
            feePercentage = fundraisingFeeConfig.tier3FeePercentage;
        }
        return feePercentage;
    }
}
