// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./ForcefiBaseContract.sol";
import "./VestingLibrary.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

interface IForcefiStaking {
    function hasStaked(address) external view returns(bool);
    function receiveFees(address, uint) external;
}

contract Fundraising is ForcefiBaseContract{
    using Counters for Counters.Counter;
    Counters.Counter _fundraisingIdCounter;

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

    struct IndividualBalances {
        mapping(address => uint) investmentTokenBalances;
        uint fundraisingTokenBalance;
    }

    struct VestingPlan {
        string label;
        uint saleStart;
        uint cliffPeriod;
        uint vestingPeriod;
        uint releasePeriod;
        uint tgePercent;
        uint totalTokenAmount;
    }

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
    }

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

    function createFundraising(FundraisingData memory _fundraisingData, address [] memory _attachedERC20Address, address _referralAddress, string memory _projectName, address _mintingErc20TokenAddress, address [] calldata _whitelistAddresses) external payable {
        bool hasCreationToken = IForcefiPackage(forcefiPackageAddress).hasCreationToken(msg.sender, _projectName);
        require(msg.value == feeAmount || hasCreationToken, "Invalid fee value or no creation token available");
        ERC20(_mintingErc20TokenAddress).transferFrom(msg.sender, address(this), _fundraisingData._totalCampaignLimit);

        FundraisingInstance memory fundraising;
        fundraising.owner = tx.origin;
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
        fundraising.mintingErc20TokenAddress = _mintingErc20TokenAddress;
        fundraising.campaignMaxTicketLimit = _fundraisingData._campaignMaxTicketLimit;

        uint fundraisingIdx = _fundraisingIdCounter.current();
        _fundraisingIdCounter.increment();

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

        emit FundraisingCreated(tx.origin, UUID, _projectName);
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

    function invest(uint256 amount, address _whitelistedTokenAddress, bytes32 _fundraisingIdx) external {
        FundraisingInstance storage fundraising = fundraisings[_fundraisingIdx];
        require(amount >= fundraising.campaignMinTicketLimit || fundraising.campaignHardCap - fundraising.totalFundraised >= amount, "Amount should be more than campaign min ticket limit");
        require(individualBalances[_fundraisingIdx][msg.sender].fundraisingTokenBalance + amount <= fundraising.campaignMaxTicketLimit, "Amount should be less than campaign max ticket limit");
        require(fundraising.campaignHardCap >= amount + fundraising.totalFundraised, "Campaign has reached its total fund raised required");
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

        // if(forcefiStakingAddress != address(0)){
        //     require(IForcefiStaking(forcefiStakingAddress).hasStaked(msg.sender), "To participate in the sale, users must stake a sufficient amount of FORC tokens.");
        // }

        require(isInvestmentToken[_whitelistedTokenAddress], "Not whitelisted investment token address");
        if(fundraising.privateFundraising){
            require(whitelistedAddresses[_fundraisingIdx][msg.sender], "not whitelisted address");
        }

        uint erc20Decimals = ERC20(_whitelistedTokenAddress).decimals();

        uint investTokenAmount = (getChainlinkDataFeedLatestAnswer(_whitelistedTokenAddress) * fundraising.rate * amount ) / fundraising.rateDelimiter / 10 ** erc20Decimals;
        individualBalances[_fundraisingIdx][msg.sender].fundraisingTokenBalance += amount;
        individualBalances[_fundraisingIdx][msg.sender].investmentTokenBalances[_whitelistedTokenAddress] += investTokenAmount;

        ERC20(_whitelistedTokenAddress).transferFrom(msg.sender, address(this), investTokenAmount);
        fundraisingBalance[_fundraisingIdx][_whitelistedTokenAddress] += investTokenAmount;

        fundraising.totalFundraised += amount;
        emit Invested(msg.sender, amount, _whitelistedTokenAddress, address(this));
    }

    function closeCampaign(bytes32 _fundraisingIdx) external isFundraisingOwner(_fundraisingIdx) {
        FundraisingInstance storage fundraising = fundraisings[_fundraisingIdx];
        require(!fundraising.campaignClosed, "Campaign already closed");
        bool hasReachedLimit = fundraising.totalFundraised > fundraising.campaignHardCap * feeConfig.minCampaignThreshold / 100;
        require(hasReachedLimit && fundraising.endDate + feeConfig.reclaimWindow >= block.timestamp, "Campaign is not yet ended or didn't reach minimal threshold");

        fundraising.campaignClosed = true;

        uint feePercentage = calculateFee(fundraising.totalFundraised);

        for(uint i=0; i< whitelistedTokens[_fundraisingIdx].length; i++){
            uint totalFundraisedInWei = fundraisingBalance[_fundraisingIdx][whitelistedTokens[_fundraisingIdx][i]];

            uint feeInWei = totalFundraisedInWei * feePercentage / 100;
            uint referralFeeInWei = totalFundraisedInWei * fundraising.fundraisingReferralFee / 100;

            if(fundraising.referralAddress != address(0)){
                ERC20(whitelistedTokens[_fundraisingIdx][i]).transfer(fundraising.referralAddress, referralFeeInWei);
            }

            ERC20(whitelistedTokens[_fundraisingIdx][i]).transfer(successfulFundraiseFeeAddress, feeInWei / 5);

            ERC20(whitelistedTokens[_fundraisingIdx][i]).approve(forcefiStakingAddress, feeInWei * 3 / 10 );
            IForcefiStaking(forcefiStakingAddress).receiveFees(whitelistedTokens[_fundraisingIdx][i], feeInWei * 3 / 10);

            ERC20(whitelistedTokens[_fundraisingIdx][i]).approve(successfulFundraiseFeeAddress, feeInWei / 2);
            IForcefiStaking(curatorContractAddress).receiveFees(whitelistedTokens[_fundraisingIdx][i], feeInWei / 2);

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

    function calculateFee(uint256 amountRaised) public view returns (uint256) {
        uint256 feePercentage;

        if (amountRaised < feeConfig.tier1Threshold) {
            feePercentage = feeConfig.tier1FeePercentage;
        } else if (amountRaised <= feeConfig.tier2Threshold) {
            feePercentage = feeConfig.tier2FeePercentage;
        } else {
            feePercentage = feeConfig.tier3FeePercentage;
        }
        return feePercentage;
    }
}
