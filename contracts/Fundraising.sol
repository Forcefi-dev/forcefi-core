// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./ForcefiBaseContract.sol";
import "./VestingLibrary.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

interface IForcefiStaking {
    function hasAddressStaked(address) external view returns(bool);
    function receiveFees(address, uint) external;
    function receiveNativeCurrencyFees() external payable;
}

interface IForcefiCuratorContract {
    function receiveCuratorFees(address, uint, bytes32) external;
    function receiveNativeCurrencyFees(bytes32) external payable;
    function getCurrentTotalPercentage(bytes32) external view returns (uint);
}

/**
 * @title Fundraising
 * @notice The Fundraising contract is designed to facilitate fundraising campaigns with vesting plans for token distribution.
 * @dev It allows project owners to create fundraising campaigns, accept investments in various tokens, and manage the vesting schedule for token distribution to investors.
 */
contract Fundraising is ForcefiBaseContract, ReentrancyGuard {

    /// @notice Counter used to generate unique fundraising IDs
    uint256 private _fundraisingIdCounter;

    /// @notice Maps token addresses to their respective Chainlink price feed interfaces
    mapping(address => AggregatorV3Interface) dataFeeds;

    /// @notice Percentage fee allocated to referrals
    uint public referralFee;

    /// @notice Address that receives fees from successful fundraising campaigns
    address public successfulFundraiseFeeAddress;

    /// @notice Address of the ForceFi staking contract
    address public forcefiStakingAddress;

    /// @notice Address of the curator contract that manages project curation
    address public curatorContractAddress;

    /// @notice Configuration for the tiered fee structure
    FeeConfig public feeConfig;

    /// @notice Maps fundraising IDs to their respective fundraising instance data
    mapping(bytes32 => FundraisingInstance) fundraisings;

    /// @notice Maps fundraising IDs to arrays of whitelisted investment token addresses
    mapping(bytes32 => address []) whitelistedTokens;

    /// @notice Maps fundraising IDs to investor addresses that are whitelisted to participate
    mapping(bytes32 => mapping(address => bool)) whitelistedAddresses;

    /// @notice Maps fundraising IDs and investor addresses to their contributed balance
    mapping(bytes32 => mapping(address => uint)) public fundraisingBalance;

    /// @notice Maps fundraising IDs and investor addresses to the amount of tokens already released through vesting
    mapping(bytes32 => mapping(address => uint)) public released;

    /// @notice Maps fundraising IDs and token addresses to their whitelist status for a specific fundraising
    mapping(bytes32 => mapping(address => bool)) whitelistedToken;

    /// @notice Maps fundraising IDs to their vesting schedule configurations
    mapping(bytes32 => VestingPlan) vestingPlans;

    /// @notice Maps token addresses to their approval status as valid investment tokens
    mapping(address => bool) public isInvestmentToken;

    /// @notice Maps fundraising IDs and investor addresses to their detailed investment balance information
    mapping(bytes32 => mapping(address => IndividualBalances)) public individualBalances;

    /// @notice Maps fundraising IDs and investor addresses to their native currency (ETH) contribution balance
    mapping(bytes32 => mapping(address => uint)) public nativeCurrencyBalance;
    
    /// @notice Maps fundraising IDs to total native currency raised
    mapping(bytes32 => uint) public totalNativeCurrencyRaised;
    
    /// @notice Stores undistributed fees for addresses (e.g., staking or curator contracts)
    mapping(address => uint256) public undistributedFees;

    /// @notice Address representing native currency (ETH) for consistency with ERC20 handling
    address public constant NATIVE_CURRENCY = address(0);

    /// @notice Maximum allowed delay for oracle price updates (24 hours)
    uint256 public constant MAX_ORACLE_DELAY = 24 hours;

    /**
     * @notice Struct to track individual balances within a fundraising campaign.
     * @param investmentTokenBalances A mapping of token addresses to their corresponding balances.
     * @param fundraisingTokenBalance The balance of fundraising tokens held by the individual.
     */
    struct IndividualBalances {
        mapping(address => uint) investmentTokenBalances;
        uint fundraisingTokenBalance;
    }

    /**
     * @notice Struct to define a vesting plan for token distribution.
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
     * @notice Struct to define the data required to create a new fundraising campaign.
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
     * @notice Struct to store details of an individual fundraising campaign.
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
     * @param fundraisingFeeConfig The fee configuration for this specific campaign.
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
     * @notice Struct to configure fee settings for fundraising campaigns.
     * @param tier1Threshold The fundraising amount threshold for tier 1 fees.
     * @param tier2Threshold The fundraising amount threshold for tier 2 fees.
     * @param tier1FeePercentage The percentage fee applied for tier 1.
     * @param tier2FeePercentage The percentage fee applied for tier 2.
     * @param tier3FeePercentage The percentage fee applied for tier 3.
     * @param minCampaignThreshold The minimum threshold percentage of the campaign hard cap that must be met for a successful campaign.
     */
    struct FeeConfig {
        uint256 tier1Threshold;
        uint256 tier2Threshold;
        uint256 tier1FeePercentage;
        uint256 tier2FeePercentage;
        uint256 tier3FeePercentage;
        uint256 minCampaignThreshold;
    }

    /**
     * @notice Emitted when a fundraising campaign is closed
     * @param owner The address of the campaign owner
     * @param timestamp The timestamp when the campaign was closed
     * @param fundraisingId The unique identifier of the fundraising campaign
     */
    event CampaignClosed(address indexed owner, uint timestamp, bytes32 fundraisingId);

    /**
     * @notice Emitted when tokens are claimed by an investor
     * @param claimer The address of the investor claiming tokens
     * @param amount The amount of tokens claimed
     */
    event TokensClaimed(address indexed claimer, uint amount);

    /**
     * @notice Emitted when investment tokens are reclaimed after a failed campaign
     * @param reclaimer The address of the investor reclaiming tokens
     * @param tokenAddress The address of the reclaimed token
     * @param amount The amount of tokens reclaimed
     */
    event TokensReclaimed(address indexed reclaimer, address tokenAddress, uint amount);

    /**
     * @notice Emitted when a new fundraising campaign is created
     * @param ownerAddress The address of the campaign owner
     * @param fundraisingId The unique identifier of the fundraising campaign
     * @param projectName The name of the project associated with the campaign
     */
    event FundraisingCreated(address indexed ownerAddress, bytes32 fundraisingId, string projectName);

    /**
     * @notice Emitted when an investment is made
     * @param investor The address of the investor
     * @param amount The amount of fundraising tokens to be received
     * @param sentTokenAddress The address of the token sent for investment
     * @param fundraisingAddress The address of the fundraising contract
     */
    event Invested(address indexed investor, uint amount, address sentTokenAddress, bytes32 indexed fundraisingAddress);

    /**
     * @notice Emitted when an address is whitelisted for a private fundraising campaign
     * @param whitelistedAddress The address that was whitelisted
     */
    event WhitelistedAddress(address whitelistedAddress);

    /**
     * @notice Emitted when a referral fee is sent
     * @param referralAddress The address receiving the referral fee
     * @param erc20TokenAddress The address of the token in which the fee was paid
     * @param projectName The name of the project
     * @param amount The amount of the referral fee
     */
    event ReferralFeeSent(address indexed referralAddress, address erc20TokenAddress, string projectName, uint amount);

    /**
     * @notice Restricts function access to the fundraising campaign owner
     * @param _fundraisingIdx The ID of the fundraising campaign
     */
    modifier isFundraisingOwner(bytes32 _fundraisingIdx){
        FundraisingInstance storage fundraising = fundraisings[_fundraisingIdx];
        require(fundraising.owner == msg.sender, "Not an owner of a fundraising");
        _;
    }

    /**
     * @notice Initializes the contract with default fee configuration
     */
    constructor() {
        feeConfig = FeeConfig({
        tier1Threshold: 1_000_000 * 1e18,
        tier2Threshold: 2_500_000 * 1e18,
        tier1FeePercentage: 5,
        tier2FeePercentage: 4,
        tier3FeePercentage: 3,
        minCampaignThreshold: 70
        });
    }
    /**
     * @notice Creates a new fundraising campaign
     * @dev Campaign can be created either if the owner of the project has a creation token or pays the fee
     * @param _fundraisingData The data required to create the fundraising campaign
     * @param _attachedERC20Address The addresses of the ERC20 tokens accepted for investment
     * @param _referralAddress The address for receiving referral fees
     * @param _projectName The name of the project
     * @param _fundraisingErc20TokenAddress The address of the ERC20 token being distributed
     * @param _whitelistAddresses The addresses to whitelist for private campaigns
     * @param _includeNativeCurrency Whether to include native currency (ETH) as an accepted investment token
     */
    function createFundraising(FundraisingData memory _fundraisingData, address [] memory _attachedERC20Address, address _referralAddress, string memory _projectName, address _fundraisingErc20TokenAddress, address [] calldata _whitelistAddresses, bool _includeNativeCurrency) external payable {
        require(_fundraisingData._tgePercent <= 100, "TGE percent cannot exceed 100");
        require(_fundraisingData._rateDelimiter > 0, "Rate delimiter cannot be zero");
        require(_fundraisingData._campaignMinTicketLimit <= _fundraisingData._campaignMaxTicketLimit, "Min ticket cannot exceed max");
        require(_fundraisingData._startDate < _fundraisingData._endDate, "Start date must be before end date");
        bool hasCreationToken = IForcefiPackage(forcefiPackageAddress).hasCreationToken(msg.sender, _projectName);
        require(msg.value == feeAmount || hasCreationToken, "Invalid fee value or no creation token available");
        ERC20(_fundraisingErc20TokenAddress).transferFrom(msg.sender, address(this), _fundraisingData._totalCampaignLimit);
        

        if(msg.value == feeAmount) {
            collectedFees += msg.value;
        }

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
        minCampaignThreshold: feeConfig.minCampaignThreshold
        });

        uint fundraisingIdx = _fundraisingIdCounter;
        _fundraisingIdCounter += 1;        bytes32 UUID = VestingLibrary.generateUUID(fundraisingIdx);
        address [] storage tokensToPush = whitelistedTokens[UUID];
        for (uint i=0; i< _attachedERC20Address.length; i++){
            require(isInvestmentToken[_attachedERC20Address[i]], "Not whitelisted investment token address");
            tokensToPush.push(_attachedERC20Address[i]);
            whitelistedToken[UUID][_attachedERC20Address[i]] = true;
        }
        
        // Add native currency if requested and globally whitelisted
        if(_includeNativeCurrency) {
            require(isInvestmentToken[NATIVE_CURRENCY], "Native currency is not globally whitelisted for investment");
            tokensToPush.push(NATIVE_CURRENCY);
            whitelistedToken[UUID][NATIVE_CURRENCY] = true;
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

    /**
     * @notice Gets the balance of a specific investment token for the caller
     * @param _idx The ID of the fundraising campaign
     * @param _investmentTokenAddress The address of the investment token
     * @return The balance of the specified investment token
     */
    function getIndividualBalanceForToken(bytes32 _idx, address _investmentTokenAddress) public view returns(uint){
        return individualBalances[_idx][msg.sender].investmentTokenBalances[_investmentTokenAddress];
    }

    /**
     * @notice Gets the native currency (ETH) balance for the caller in a specific campaign
     * @param _idx The ID of the fundraising campaign
     * @return The balance of native currency contributed by the caller
     */
    function getNativeCurrencyBalance(bytes32 _idx) public view returns(uint){
        return nativeCurrencyBalance[_idx][msg.sender];
    }

    /**
     * @notice Gets the total native currency raised for a specific campaign
     * @param _idx The ID of the fundraising campaign
     * @return The total amount of native currency raised
     */
    function getTotalNativeCurrencyRaised(bytes32 _idx) public view returns(uint){
        return totalNativeCurrencyRaised[_idx];
    }

    /**
     * @notice Retrieves details of a fundraising campaign
     * @param _idx The ID of the fundraising campaign
     * @return The FundraisingInstance struct with campaign details
     */
    function getFundraisingInstance(bytes32 _idx) public view returns (FundraisingInstance memory){
        return fundraisings[_idx];
    }

    /**
     * @notice Retrieves the vesting plan for a fundraising campaign
     * @param _idx The ID of the fundraising campaign
     * @return The VestingPlan struct with vesting details
     */
    function getVestingPlan(bytes32 _idx) public view returns (VestingPlan memory){
        return vestingPlans[_idx];
    }

    /**
     * @notice Retrieves the list of whitelisted investment tokens for a campaign
     * @param _idx The ID of the fundraising campaign
     * @return An array of token addresses that are whitelisted for the campaign
     */
    function getWhitelistedTokens(bytes32 _idx) public view returns(address[] memory){
        return whitelistedTokens[_idx];
    }

    /**
     * @notice Sets the address to which successful fundraising fees are sent
     * @param _successfulFundraiseFeeAddress The address to receive fees
     */
    function setSuccessfulFundraisingFeeAddress(address _successfulFundraiseFeeAddress) external onlyOwner {
        successfulFundraiseFeeAddress = _successfulFundraiseFeeAddress;
    }

    /**
     * @notice Adds addresses to the whitelist for a private fundraising campaign
     * @param _whitelistAddress An array of addresses to whitelist
     * @param _fundraisingIdx The ID of the fundraising campaign
     */
    function addWhitelistAddress(address [] calldata _whitelistAddress, bytes32 _fundraisingIdx) public isFundraisingOwner(_fundraisingIdx) {
        for(uint i = 0; i< _whitelistAddress.length; i++){
            whitelistedAddresses[_fundraisingIdx][_whitelistAddress[i]] = true;
            emit WhitelistedAddress(_whitelistAddress[i]);
        }
    }

    /**
     * @notice Updates the fee configuration
     * @param _tier1Threshold The threshold for tier 1 fees
     * @param _tier2Threshold The threshold for tier 2 fees
     * @param _tier1FeePercentage The percentage for tier 1 fees
     * @param _tier2FeePercentage The percentage for tier 2 fees
     * @param _tier3FeePercentage The percentage for tier 3 fees
     * @param _minCampaignThreshold The minimum threshold for a successful campaign
     */
    function setFeeConfig(uint256 _tier1Threshold, uint256 _tier2Threshold, uint256 _tier1FeePercentage, uint256 _tier2FeePercentage, uint256 _tier3FeePercentage, uint256 _minCampaignThreshold) external onlyOwner {
        feeConfig = FeeConfig({
        tier1Threshold: _tier1Threshold,
        tier2Threshold: _tier2Threshold,
        tier1FeePercentage: _tier1FeePercentage,
        tier2FeePercentage: _tier2FeePercentage,
        tier3FeePercentage: _tier3FeePercentage,
        minCampaignThreshold: _minCampaignThreshold
        });
    }
    
    /**
     * @notice Allows users to invest in a fundraising campaign
     * @dev Requires users to stake FORC tokens and the campaign to be active
     * @param _amount The amount of tokens to invest
     * @param _whitelistedTokenAddress The address of the token being sent for investment
     * @param _fundraisingIdx The ID of the campaign to invest in
     */
    function invest(uint256 _amount, address _whitelistedTokenAddress, bytes32 _fundraisingIdx) external nonReentrant {
        FundraisingInstance storage fundraising = fundraisings[_fundraisingIdx];
        require(_amount >= fundraising.campaignMinTicketLimit || fundraising.campaignHardCap - fundraising.totalFundraised <= fundraising.campaignMinTicketLimit, "Amount should be more than campaign min ticket limit");
        require(individualBalances[_fundraisingIdx][msg.sender].fundraisingTokenBalance + _amount <= fundraising.campaignMaxTicketLimit, "Amount should be less than campaign max ticket limit");
        require(fundraising.campaignHardCap >= _amount + fundraising.totalFundraised, "Campaign has reached its total fund raised required");
        require(block.timestamp >= fundraising.startDate, "Campaign hasn't started yet");        
        require(!fundraising.campaignClosed, "Campaign is closed");
        require(block.timestamp <= fundraising.endDate, "Campaign has ended");

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

        if(fundraising.privateFundraising){
            require(whitelistedAddresses[_fundraisingIdx][msg.sender], "not whitelisted address");
        }

        uint erc20Decimals = ERC20(_whitelistedTokenAddress).decimals();

        uint paymentTokenPrice = getChainlinkDataFeedLatestAnswer(_whitelistedTokenAddress);
        uint totalCostInPaymentTokenDecimals = (_amount * fundraising.rate * (10 ** erc20Decimals)) / (fundraising.rateDelimiter * paymentTokenPrice);
        
        individualBalances[_fundraisingIdx][msg.sender].fundraisingTokenBalance += _amount;
        individualBalances[_fundraisingIdx][msg.sender].investmentTokenBalances[_whitelistedTokenAddress] += totalCostInPaymentTokenDecimals;
        ERC20(_whitelistedTokenAddress).transferFrom(msg.sender, address(this), totalCostInPaymentTokenDecimals);
        fundraisingBalance[_fundraisingIdx][_whitelistedTokenAddress] += totalCostInPaymentTokenDecimals;

        fundraising.totalFundraised += _amount;
        emit Invested(msg.sender, _amount, _whitelistedTokenAddress, _fundraisingIdx);
    }
    
    /**
     * @notice Allows users to invest in a fundraising campaign using native currency (ETH)
     * @dev Requires users to stake FORC tokens and the campaign to be active. Native currency must be enabled for the campaign.
     * @param _amount The amount of fundraising tokens to receive (not the ETH amount sent)
     * @param _fundraisingIdx The ID of the campaign to invest in
     */
    function investWithNativeCurrency(uint256 _amount, bytes32 _fundraisingIdx) external payable nonReentrant {
        FundraisingInstance storage fundraising = fundraisings[_fundraisingIdx];
        require(_amount >= fundraising.campaignMinTicketLimit || fundraising.campaignHardCap - fundraising.totalFundraised <= fundraising.campaignMinTicketLimit, "Amount should be more than campaign min ticket limit");
        require(individualBalances[_fundraisingIdx][msg.sender].fundraisingTokenBalance + _amount <= fundraising.campaignMaxTicketLimit, "Amount should be less than campaign max ticket limit");
        require(fundraising.campaignHardCap >= _amount + fundraising.totalFundraised, "Campaign has reached its total fund raised required");
        require(block.timestamp >= fundraising.startDate, "Campaign hasn't started yet");        
        require(!fundraising.campaignClosed, "Campaign is closed");
        require(block.timestamp <= fundraising.endDate, "Campaign has ended");

        // Check if native currency is whitelisted for this campaign
        bool isNativeCurrencyWhitelisted = false;
        for(uint i=0; i< whitelistedTokens[_fundraisingIdx].length; i++){
            if(whitelistedTokens[_fundraisingIdx][i] == NATIVE_CURRENCY){
                isNativeCurrencyWhitelisted = true;
                break;
            }
        }
        require(isNativeCurrencyWhitelisted, "Native currency is not whitelisted for this campaign");

        if(forcefiStakingAddress != address(0)){
            require(IForcefiStaking(forcefiStakingAddress).hasAddressStaked(msg.sender), "To participate in the sale, users must stake a sufficient amount of FORC tokens.");
        }

        if(fundraising.privateFundraising){
            require(whitelistedAddresses[_fundraisingIdx][msg.sender], "not whitelisted address");
        }
        
        uint ethPrice = getChainlinkDataFeedLatestAnswer(NATIVE_CURRENCY);
        uint requiredEthAmount = (_amount * fundraising.rate * 1e18) / (fundraising.rateDelimiter * ethPrice);
        
        require(msg.value >= requiredEthAmount, "Insufficient ETH sent");

        // Update balances
        individualBalances[_fundraisingIdx][msg.sender].fundraisingTokenBalance += _amount;
        nativeCurrencyBalance[_fundraisingIdx][msg.sender] += requiredEthAmount;
        totalNativeCurrencyRaised[_fundraisingIdx] += requiredEthAmount;

        fundraising.totalFundraised += _amount;

        // Refund excess ETH if any
        if(msg.value > requiredEthAmount) {
            payable(msg.sender).transfer(msg.value - requiredEthAmount);
        }

        emit Invested(msg.sender, _amount, NATIVE_CURRENCY, _fundraisingIdx);
    }
    
    /**
     * @notice Closes a fundraising campaign
     * @dev To close, the campaign must reach its minimum threshold after end date + reclaim window
     * @param _fundraisingIdx The ID of the campaign to close
     */
    function closeCampaign(bytes32 _fundraisingIdx) external isFundraisingOwner(_fundraisingIdx) nonReentrant {
        FundraisingInstance storage fundraising = fundraisings[_fundraisingIdx];
        require(!fundraising.campaignClosed, "Campaign already closed");
        
        bool hasReachedLimit = fundraising.totalFundraised > fundraising.campaignHardCap * fundraising.fundraisingFeeConfig.minCampaignThreshold / 100;
        require(hasReachedLimit, "Campaign didn't reach minimal threshold");
        require(fundraising.endDate <= block.timestamp, "Campaign is still within reclaim window");

        fundraising.campaignClosed = true;
        uint feePercentage = calculateFee(fundraising.totalFundraised, fundraising.fundraisingFeeConfig);
        
        // Handle ERC20 tokens
        for(uint i=0; i < whitelistedTokens[_fundraisingIdx].length; i++) {
            address tokenAddress = whitelistedTokens[_fundraisingIdx][i];
            
            if(tokenAddress == NATIVE_CURRENCY) {
                // Handle native currency (ETH)
                uint totalFundraisedInWei = totalNativeCurrencyRaised[_fundraisingIdx];
                if(totalFundraisedInWei > 0) {
                    uint feeInWei = totalFundraisedInWei * feePercentage / 100;
                    uint distributedFees = 0;

                    // Calculate referral fee from base fee pool (if referral exists)
                    uint referralFeeInWei = 0;
                    if(fundraising.referralAddress != address(0) && fundraising.fundraisingReferralFee > 0) {
                        referralFeeInWei = feeInWei * fundraising.fundraisingReferralFee / 100;
                        payable(fundraising.referralAddress).transfer(referralFeeInWei);
                        emit ReferralFeeSent(fundraising.referralAddress, NATIVE_CURRENCY, fundraising.projectName, referralFeeInWei);
                        distributedFees += referralFeeInWei;
                    }
                    // Calculate remaining base fee after referral deduction
                    uint remainingBaseFee = feeInWei - referralFeeInWei;

                    // Handle platform fee (1/5 of the remaining base fee)
                    if(successfulFundraiseFeeAddress != address(0)) {
                        uint platformFee = remainingBaseFee / 5;
                        payable(successfulFundraiseFeeAddress).transfer(platformFee);
                        distributedFees += platformFee;
                    }

                    // Handle staking fee (3/10 of the remaining base fee) for native currency
                    if(forcefiStakingAddress != address(0)) {
                        uint stakingFee = remainingBaseFee * 3 / 10;
                        // Try to send ETH to staking contract
                        try IForcefiStaking(forcefiStakingAddress).receiveNativeCurrencyFees{value: stakingFee}() {
                            distributedFees += stakingFee;
                        } catch {
                            undistributedFees[forcefiStakingAddress] += stakingFee;
                        }                         
                    }

                    // Handle curator fee (1/2 of the remaining base fee) for native currency
                    if(curatorContractAddress != address(0)) {
                        uint curatorFee = remainingBaseFee / 2;
                        uint curatorPercentage = IForcefiCuratorContract(curatorContractAddress).getCurrentTotalPercentage(_fundraisingIdx);
                        uint adjustedCuratorFee = curatorFee * curatorPercentage / 100;
                        if (adjustedCuratorFee > 0) {
                            // Try to send ETH to curator contract
                            try IForcefiCuratorContract(curatorContractAddress).receiveNativeCurrencyFees{value: adjustedCuratorFee}(_fundraisingIdx) {
                                distributedFees += adjustedCuratorFee;
                            } catch {
                                // If curator contract doesn't support ETH, we store funds in the contract and allow to withdraw them for respective address
                                undistributedFees[curatorContractAddress] += adjustedCuratorFee;
                            }
                        }
                    }

                    // Calculate total amount to send to msg.sender
                    uint amountToSender = totalFundraisedInWei - distributedFees;
                    payable(msg.sender).transfer(amountToSender);
                }
            } else {
                // Handle ERC20 tokens
                uint totalFundraisedInWei = fundraisingBalance[_fundraisingIdx][tokenAddress];
                if(totalFundraisedInWei > 0) {
                    uint feeInWei = totalFundraisedInWei * feePercentage / 100;
                    uint distributedFees = 0;

                    // Calculate referral fee from base fee pool (if referral exists)
                    uint referralFeeInWei = 0;
                    if(fundraising.referralAddress != address(0) && fundraising.fundraisingReferralFee > 0) {
                        referralFeeInWei = feeInWei * fundraising.fundraisingReferralFee / 100;
                        ERC20(tokenAddress).transfer(fundraising.referralAddress, referralFeeInWei);
                        emit ReferralFeeSent(fundraising.referralAddress, tokenAddress, fundraising.projectName, referralFeeInWei);
                        distributedFees += referralFeeInWei;
                    }

                    // Calculate remaining base fee after referral deduction
                    uint remainingBaseFee = feeInWei - referralFeeInWei;

                    // Handle platform fee (1/5 of the remaining base fee)
                    if(successfulFundraiseFeeAddress != address(0)) {
                        uint platformFee = remainingBaseFee / 5;
                        ERC20(tokenAddress).transfer(successfulFundraiseFeeAddress, platformFee);
                        distributedFees += platformFee;
                    }

                    // Handle staking fee (3/10 of the remaining base fee)
                    if(forcefiStakingAddress != address(0)) {
                        uint stakingFee = remainingBaseFee * 3 / 10;
                        ERC20(tokenAddress).approve(forcefiStakingAddress, stakingFee);
                        IForcefiStaking(forcefiStakingAddress).receiveFees(tokenAddress, stakingFee);
                        distributedFees += stakingFee;
                    }

                    // Handle curator fee (1/2 of the remaining base fee)
                    if(curatorContractAddress != address(0)) {
                        uint curatorFee = remainingBaseFee / 2;
                        uint curatorPercentage = IForcefiCuratorContract(curatorContractAddress).getCurrentTotalPercentage(_fundraisingIdx);
                        uint adjustedCuratorFee = curatorFee * curatorPercentage / 100;
                        if (adjustedCuratorFee > 0) {
                            ERC20(tokenAddress).approve(curatorContractAddress, adjustedCuratorFee);
                            IForcefiCuratorContract(curatorContractAddress).receiveCuratorFees(tokenAddress, adjustedCuratorFee, _fundraisingIdx);
                            distributedFees += adjustedCuratorFee;
                        }
                    }

                    // Calculate total amount to send to msg.sender
                    uint amountToSender = totalFundraisedInWei - distributedFees;
                    ERC20(tokenAddress).transfer(msg.sender, amountToSender);
                }
            }
        }

        if(fundraising.campaignHardCap > fundraising.totalFundraised){
            ERC20(fundraising.mintingErc20TokenAddress).transfer(msg.sender, fundraising.campaignHardCap - fundraising.totalFundraised);
        }

        emit CampaignClosed(msg.sender, block.timestamp, _fundraisingIdx);
    }

    /**
     * @notice Unlocks funds from a failed campaign and returns them to the owner
     * @dev Only callable by the campaign owner
     * @param _fundraisingIdx The ID of the campaign
     */
    function unlockFundsFromCampaign(bytes32 _fundraisingIdx) external isFundraisingOwner(_fundraisingIdx) {
        FundraisingInstance storage fundraising = fundraisings[_fundraisingIdx];
        require(!fundraising.campaignClosed, "Campaign already closed");
        require(block.timestamp >= fundraising.endDate, "Campaign end date has not passed");
        
        bool hasReachedLimit = fundraising.totalFundraised > fundraising.campaignHardCap * feeConfig.minCampaignThreshold / 100;
        require(!hasReachedLimit, "Campaign has reached minimal threshold");

        fundraising.campaignClosed = true;
        ERC20(fundraising.mintingErc20TokenAddress).transfer(msg.sender, fundraising.campaignHardCap);
    }
    
    /**
     * @notice Allows investors to claim their tokens based on the vesting schedule
     * @dev Only available after a successful campaign has been completed
     * @param _fundraisingIdx The ID of the campaign to claim tokens from
     */
    function claimTokens(bytes32 _fundraisingIdx) external nonReentrant {
        FundraisingInstance storage fundraising = fundraisings[_fundraisingIdx];
        bool hasReachedLimit = fundraising.totalFundraised > fundraising.campaignHardCap * feeConfig.minCampaignThreshold / 100;

        require(hasReachedLimit && block.timestamp >= fundraising.endDate, "Campaign isnt closed");

        uint256 vestedAmount = computeReleasableAmount(_fundraisingIdx);
        require(vestedAmount > 0, "TokenVesting: cannot release tokens, no vested tokens");

        released[_fundraisingIdx][msg.sender] += vestedAmount;
        ERC20(fundraising.mintingErc20TokenAddress).transfer(msg.sender, vestedAmount);
        emit TokensClaimed(msg.sender, vestedAmount);
    }

    /**
     * @notice Calculates the amount of tokens available to be claimed
     * @param _fundraisingIdx The ID of the fundraising campaign
     * @return The amount of tokens that can be released
     */
    function computeReleasableAmount(bytes32 _fundraisingIdx) public view returns(uint256){
        require(vestingPlans[_fundraisingIdx].saleStart < block.timestamp, "TokenVesting: this vesting has not started yet");
        uint mintingTokenAmount = individualBalances[_fundraisingIdx][msg.sender].fundraisingTokenBalance;
        return VestingLibrary.computeReleasableAmount(vestingPlans[_fundraisingIdx].saleStart, vestingPlans[_fundraisingIdx].vestingPeriod, vestingPlans[_fundraisingIdx].releasePeriod, vestingPlans[_fundraisingIdx].cliffPeriod, vestingPlans[_fundraisingIdx].tgePercent, mintingTokenAmount, released[_fundraisingIdx][msg.sender]);
    }
    
    /**
     * @notice Allows investors to reclaim their tokens if a campaign fails
     * @dev Available after campaign end date if threshold wasn't met
     * @param _fundraisingIdx The ID of the campaign
     */
    function reclaimTokens(bytes32 _fundraisingIdx) external nonReentrant {
        FundraisingInstance storage fundraising = fundraisings[_fundraisingIdx];
        require(block.timestamp >= fundraising.endDate, "Campaign has not ended");
        
        bool hasReachedLimit = fundraising.totalFundraised > fundraising.campaignHardCap * feeConfig.minCampaignThreshold / 100;
        require(!hasReachedLimit, "Cannot reclaim from a successful campaign");

        for(uint i=0; i< whitelistedTokens[_fundraisingIdx].length; i++){
            address tokenAddress = whitelistedTokens[_fundraisingIdx][i];
            
            if(tokenAddress == NATIVE_CURRENCY) {
                // Handle native currency (ETH)
                uint reclaimAmount = nativeCurrencyBalance[_fundraisingIdx][msg.sender];
                if(reclaimAmount > 0){
                    nativeCurrencyBalance[_fundraisingIdx][msg.sender] = 0;
                    totalNativeCurrencyRaised[_fundraisingIdx] -= reclaimAmount;
                    payable(msg.sender).transfer(reclaimAmount);
                    emit TokensReclaimed(msg.sender, NATIVE_CURRENCY, reclaimAmount);
                }
            } else {
                // Handle ERC20 tokens
                uint reclaimAmount = individualBalances[_fundraisingIdx][msg.sender].investmentTokenBalances[tokenAddress];
                if(reclaimAmount > 0){
                    individualBalances[_fundraisingIdx][msg.sender].investmentTokenBalances[tokenAddress] = 0;
                    ERC20(tokenAddress).transfer(msg.sender, reclaimAmount);
                    emit TokensReclaimed(msg.sender, tokenAddress, reclaimAmount);
                }
            }
        }

        fundraising.totalFundraised -= individualBalances[_fundraisingIdx][msg.sender].fundraisingTokenBalance;
        individualBalances[_fundraisingIdx][msg.sender].fundraisingTokenBalance = 0;
    }
    /**
     * @notice Allows the ForceFi staking contract or curator contract to release undistributed fees
     * @dev Only callable by the staking or curator contract
     */
    function releaseUndistributedFees() external nonReentrant(){
        require(undistributedFees[msg.sender] > 0, "No undistributed fees for this address");
        require(msg.sender == forcefiStakingAddress || msg.sender == curatorContractAddress, "Only staking or curator contract can withdraw undistributed fees");
        uint amount = undistributedFees[msg.sender];
        undistributedFees[msg.sender] = 0;

        payable(msg.sender).transfer(amount);
     }

    /**
     * @notice Sets the referral fee percentage
     * @param _referralFee The new referral fee percentage
     */
    function setReferralFee(uint _referralFee) external onlyOwner {
        referralFee = _referralFee;
    }

    /**
     * @notice Sets the address of the ForceFi staking contract
     * @dev Can only be called by the contract owner
     * @param _forcefiStakingAddress The address of the ForceFi staking contract
     */
    function setForcefiStakingAddress(address _forcefiStakingAddress) external onlyOwner {
        forcefiStakingAddress = _forcefiStakingAddress;
    }

    /**
     * @notice Sets the address of the curators contract
     * @dev Can only be called by the contract owner
     * @param _curatorContractAddress The address of the curators contract
     */
    function setCuratorsContractAddress(address _curatorContractAddress) external onlyOwner {
        curatorContractAddress = _curatorContractAddress;
    }

    /**
     * @notice Whitelists a token for investment and associates it with a Chainlink data feed
     * @dev Can only be called by the contract owner
     * @param _investmentTokenAddress The address of the token to whitelist
     * @param _dataFeedAddress The address of the Chainlink data feed for price conversion
     */
    function whitelistTokenForInvestment(address _investmentTokenAddress, address _dataFeedAddress) external onlyOwner {
        isInvestmentToken[_investmentTokenAddress] = true;
        dataFeeds[_investmentTokenAddress] = AggregatorV3Interface(_dataFeedAddress);
    }

    /**
     * @notice Whitelists native currency (ETH) for investment and associates it with a Chainlink data feed
     * @dev Can only be called by the contract owner
     * @param _dataFeedAddress The address of the Chainlink ETH/USD data feed for price conversion
     */
    function whitelistNativeCurrencyForInvestment(address _dataFeedAddress) external onlyOwner {
        isInvestmentToken[NATIVE_CURRENCY] = true;
        dataFeeds[NATIVE_CURRENCY] = AggregatorV3Interface(_dataFeedAddress);
    }
    
    /**
     * @notice Gets the latest price from a Chainlink data feed for a specified token
     * @dev Handles decimal conversion between token and data feed and validates oracle data
     * @param _erc20TokenAddress The address of the ERC20 token
     * @return uint256 The latest price from the data feed with adjusted decimals
     */    function getChainlinkDataFeedLatestAnswer(address _erc20TokenAddress) public view returns (uint256) {
        AggregatorV3Interface dataFeed = dataFeeds[_erc20TokenAddress];

        (
        uint80 roundID,
        int answer,
        uint startedAt,
        uint timeStamp,
        uint80 answeredInRound
        ) = dataFeed.latestRoundData();

        // Validate oracle data
        require(answer > 0, "Oracle: Invalid price data");
        require(timeStamp > 0, "Oracle: Round not complete");
        require(block.timestamp - timeStamp < MAX_ORACLE_DELAY, "Oracle: Stale price data");
        require(answeredInRound >= roundID, "Oracle: Stale round data");

        uint erc20Decimals;
        if (_erc20TokenAddress == NATIVE_CURRENCY) {
            erc20Decimals = 18; // ETH has 18 decimals
        } else {
            erc20Decimals = ERC20(_erc20TokenAddress).decimals();
        }
        
        uint256 decimals = uint256(dataFeed.decimals());
        uint256 chainlinkPrice = uint256(answer);

        if(erc20Decimals > decimals){
            return chainlinkPrice * (10 ** (erc20Decimals - decimals));
        } else if(decimals > erc20Decimals) {
            return chainlinkPrice / (10 ** (decimals - erc20Decimals));
        } else {
            return chainlinkPrice;
        }
    }

    /**
     * @notice Calculates the fee amount based on the amount raised and fee configuration
     * @dev Uses a tiered fee structure based on predefined thresholds
     * @param amountRaised The total amount that has been raised
     * @param fundraisingFeeConfig The fee configuration containing thresholds and percentages
     * @return uint256 The calculated fee percentage
     */
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
