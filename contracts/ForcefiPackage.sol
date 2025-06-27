// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import { OApp, MessagingFee, Origin } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OApp.sol";
import { MessagingReceipt } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OAppSender.sol";

/**
 * @title ILzContract
 * @dev Interface for LayerZero cross-chain communication contract.
 */
interface ILzContract {
    function send(address, string memory) external;
}

/**
 * @title ForcefiPackage
 * @dev Main contract for managing investment packages and package purchases.
 */
contract ForcefiPackage is Ownable, OApp {
    mapping(address => AggregatorV3Interface) dataFeeds;

    // Structure defining the properties of an investment package
    struct Package {
        string label;
        uint256 amount;
        bool isCustom;
        uint256 referralFee;
        bool benefitsEnabled;
    }

    // Array of available packages
    Package[] public packages;

    // Mapping to track whitelisted ERC20 tokens for investment
    mapping(address => bool) public whitelistedToken;

    // Mapping to track purchased packages by project name
    mapping(string => string[]) individualPackages;

    // Mapping to track the amount invested by each project
    mapping(string => uint256) public amountInvestedByProject;

    // Mapping to track whether a creation token exists for a specific project and owner
    mapping(address => mapping(string => bool)) private creationTokens;

    // Event emitted when a package is bought
    event PackageBought(string projectName, string tier, address indexed buyer);

    // Event emitted when a referral gets fee from package bought
    event ReferralFeeSent(string _projectName, address indexed _referralAddress, uint referralFee);

    event TokenBridged(uint32 _destChainId, string _projectName, address indexed _projectOwner);

    /**
     * @notice Emitted when a new package is added
     * @param label The label of the package
     * @param amount The amount of the package
     * @param isCustom Whether the package is custom
     * @param referralFee The referral fee percentage
     * @param benefitsEnabled Whether benefits are enabled
     */
    event PackageAdded(string label, uint256 amount, bool isCustom, uint256 referralFee, bool benefitsEnabled);

    /**
     * @notice Emitted when a package is updated
     * @param label The label of the package
     * @param oldAmount The previous amount
     * @param newAmount The new amount
     * @param oldIsCustom The previous custom status
     * @param newIsCustom The new custom status
     * @param oldReferralFee The previous referral fee
     * @param newReferralFee The new referral fee
     */
    event PackageUpdated(
        string label,
        uint256 oldAmount,
        uint256 newAmount,
        bool oldIsCustom,
        bool newIsCustom,
        uint256 oldReferralFee,
        uint256 newReferralFee
    );

    /**
     * @notice Emitted when a creation token is minted by owner
     * @param tokenHolder The address that received the token
     * @param projectName The project name
     */
    event OwnerMintedToken(address indexed tokenHolder, string projectName);

    /**
     * @notice Emitted when a token is whitelisted for investment
     * @param tokenAddress The address of the whitelisted token
     * @param dataFeedAddress The address of the associated data feed
     */
    event TokenWhitelistedForInvestment(address indexed tokenAddress, address indexed dataFeedAddress);

    /**
     * @notice Emitted when a token is removed from whitelist
     * @param tokenAddress The address of the token removed from whitelist
     */
    event TokenRemovedFromWhitelist(address indexed tokenAddress);

    /**
     * @notice Emitted when tokens are withdrawn
     * @param tokenContract The address of the token contract
     * @param recipient The address that received the tokens
     * @param amount The amount withdrawn
     */
    event TokensWithdrawn(address indexed tokenContract, address indexed recipient, uint256 amount);

    /**
     * @dev Constructor to initialize the contract with the LayerZero contract address and default packages.
    */
    constructor(address _endpoint, address _delegate) OApp(_endpoint, _delegate) Ownable(_delegate) {
        addPackage("Explorer", 750, false, 5, false);      // Adding default "Explorer" package
        addPackage("Accelerator", 2000, false, 5, true);   // Adding default "Accelerator" package
    }

    /**
    * @dev Internal function override to handle incoming messages from another chain.
     * @dev _origin A struct containing information about the message sender.
     * @dev _guid A unique global packet identifier for the message.
     * @param payload The encoded message payload being received.
     *
     * @dev The following params are unused in the current implementation of the OApp.
     * @dev _executor The address of the Executor responsible for processing the message.
     * @dev _extraData Arbitrary data appended by the Executor to the message.
     *
     * Decodes the received payload and processes it as per the business logic defined in the function.
     */
    function _lzReceive(
        Origin calldata /*_origin*/,
        bytes32 /*_guid*/,
        bytes calldata payload,
        address /*_executor*/,
        bytes calldata /*_extraData*/
    ) internal override {
        (address _tokenOwner, string memory _projectName) = abi.decode(payload, (address, string));
        _mintPackageToken(_tokenOwner, _projectName);
    }

    /**
    * @notice Quotes the gas needed to pay for the full omnichain transaction in native gas or ZRO token.
     * @param _dstEid Destination chain's endpoint ID.
     * @param _message The message.
     * @param _options Message execution options (e.g., for sending gas to destination).
     * @param _payInLzToken Whether to return fee in ZRO token.
     * @return fee A `MessagingFee` struct containing the calculated gas fee in either the native token or ZRO token.
     */
    function quote(
        uint32 _dstEid,
        string memory _message,
        bytes memory _options,
        bool _payInLzToken
    ) public view returns (MessagingFee memory fee) {
        bytes memory payload = abi.encode(_message);
        fee = _quote(_dstEid, payload, _options, _payInLzToken);
    }

    /**
     * @dev Adds a new package to the list of available packages.
     * @param _label Name of the package.
     * @param _amount Cost of the package in base currency.
     * @param _isCustom Whether the package is custom or not.
     * @param _referralFee Referral fee as a percentage.
     * @param _benefitsEnabled If the package includes benefits like token minting.
     */
    function addPackage(string memory _label, uint256 _amount, bool _isCustom, uint256 _referralFee, bool _benefitsEnabled) public onlyOwner {
        Package memory newTier = Package({
            label: _label,
            amount: _amount,
            isCustom: _isCustom,
            referralFee: _referralFee,
            benefitsEnabled: _benefitsEnabled
        });

        packages.push(newTier);
        emit PackageAdded(_label, _amount, _isCustom, _referralFee, _benefitsEnabled);
    }

    /**
     * @dev Updates an existing package's details.
     * @param _label Name of the package to update.
     * @param newAmount New cost of the package.
     * @param newIsCustom New custom status of the package.
     * @param newReferralFee New referral fee percentage.
     */
    function updatePackage(string memory _label, uint256 newAmount, bool newIsCustom, uint256 newReferralFee) external onlyOwner {
        Package storage packageToUpdate = getPackageByLabel(_label);  // Retrieve the package by label
        uint256 oldAmount = packageToUpdate.amount;
        bool oldIsCustom = packageToUpdate.isCustom;
        uint256 oldReferralFee = packageToUpdate.referralFee;

        packageToUpdate.amount = newAmount;
        packageToUpdate.isCustom = newIsCustom;
        packageToUpdate.referralFee = newReferralFee;

        emit PackageUpdated(_label, oldAmount, newAmount, oldIsCustom, newIsCustom, oldReferralFee, newReferralFee);
    }

    /**
     * @dev Private function to retrieve a package by its label.
     * @param label Label of the package to retrieve.
     * @return Package storage The package matching the label.
     */
    function getPackageByLabel(string memory label) private view returns (Package storage) {
        for (uint256 i = 0; i < packages.length; i++) {
            if (keccak256(abi.encodePacked(packages[i].label)) == keccak256(abi.encodePacked(label))) {
                return packages[i];
            }
        }

        revert("Package not found");
    }

    /**
     * @dev Allows a project to purchase a package using a whitelisted ERC20 token.
     * @param _projectName Name of the project buying the package.
     * @param _packageLabel Label of the package being purchased.
     * @param _erc20TokenAddress Address of the ERC20 token used for payment.
     * @param _referralAddress Address to receive the referral fee.
     */
    function buyPackage(string memory _projectName, string memory _packageLabel, address _erc20TokenAddress, address _referralAddress) external {
        require(whitelistedToken[_erc20TokenAddress], "Not whitelisted investment token");  // Check if the token is whitelisted
        Package memory package = getPackageByLabel(_packageLabel);  // Retrieve the package by label
        require(!checkForExistingPackage(package, _projectName), "Project has already bought this package");  // Ensure package hasn't been purchased before
        uint256 amountToPay = package.amount;
        if (!package.isCustom) {
            amountToPay = package.amount - amountInvestedByProject[_projectName];  // Calculate amount based on previous investments
            amountInvestedByProject[_projectName] += amountToPay;
            if (package.benefitsEnabled) {
                _mintPackageToken(msg.sender, _projectName);
            }
        }

        uint256 finalAmountToPay = uint256(getChainlinkDataFeedLatestAnswer(_erc20TokenAddress)) * amountToPay;

        uint256 referralFee = 0;
        if (_referralAddress != address(0)) {
            referralFee = finalAmountToPay * package.referralFee / 100;  // Calculate referral fee
            ERC20(_erc20TokenAddress).transferFrom(msg.sender, _referralAddress, referralFee);  // Transfer referral fee
            emit ReferralFeeSent(_projectName, _referralAddress, referralFee);
        }

        uint256 packagePaymentCost = finalAmountToPay - referralFee;

        ERC20(_erc20TokenAddress).transferFrom(msg.sender, address(this), packagePaymentCost);

        individualPackages[_projectName].push(_packageLabel);
        emit PackageBought(_projectName, _packageLabel, msg.sender);
    }

    /**
     * @dev Private function to mint a creation token for a specific project and owner.
     * @param _tokenOwner Address of the token owner.
     * @param _projectName Name of the project associated with the token.
     */
    function _mintPackageToken(address _tokenOwner, string memory _projectName) private {
        creationTokens[_tokenOwner][_projectName] = true;
    }

    /**
     * @dev Checks if a creation token exists for a specific project and owner.
     * @param _tokenOwner Address of the token owner.
     * @param _projectName Name of the project to check.
     * @return bool True if the creation token exists, otherwise false.
     */
    function hasCreationToken(address _tokenOwner, string memory _projectName) external view returns(bool) {
        return creationTokens[_tokenOwner][_projectName];
    }

    /**
     * @dev Function to bridge a creation token to another blockchain.
     * @param _destChainId Destination chain ID.
     * @param _projectName Name of the project associated with the token.
     */
    function bridgeToken(uint32 _destChainId, string memory _projectName, bytes calldata _options) external payable returns (MessagingReceipt memory receipt){
        require(creationTokens[msg.sender][_projectName], "No token to bridge");
        bytes memory payload = abi.encode(msg.sender, _projectName);
        _lzSend(_destChainId, payload, _options, MessagingFee(msg.value, 0), payable(msg.sender));
        emit TokenBridged(_destChainId, _projectName, msg.sender);
    }    /**
     * @dev Mint a creation token by the contract owner.
     * @param _tokenHolder Address of the token holder.
     * @param _projectName Name of the project associated with the token.
     */
    function ownerMintToken(address _tokenHolder, string memory _projectName) public onlyOwner {
        require(_tokenHolder != address(0), "Token holder address cannot be zero");
        _mintPackageToken(_tokenHolder, _projectName);
        emit OwnerMintedToken(_tokenHolder, _projectName);
    }    /**
     * @dev Whitelist an ERC20 token for investment.
     * @param _whitelistedTokenAddress Address of the ERC20 token to whitelist.
     * @param _dataFeedAddress Address of the Chainlink data feed (currently commented out).
     */
    function whitelistTokenForInvestment(address _whitelistedTokenAddress, address _dataFeedAddress) external onlyOwner {
        require(_whitelistedTokenAddress != address(0), "Token address cannot be zero");
        require(_dataFeedAddress != address(0), "Data feed address cannot be zero");
        whitelistedToken[_whitelistedTokenAddress] = true;
        dataFeeds[_whitelistedTokenAddress] = AggregatorV3Interface(_dataFeedAddress);
        emit TokenWhitelistedForInvestment(_whitelistedTokenAddress, _dataFeedAddress);
    }    /**
     * @dev Remove an ERC20 token from the whitelist.
     * @param _whitelistedTokenAddress Address of the ERC20 token to remove.
     */
    function removeWhitelistInvestmentToken(address _whitelistedTokenAddress) external onlyOwner {
        require(_whitelistedTokenAddress != address(0), "Token address cannot be zero");
        whitelistedToken[_whitelistedTokenAddress] = false;
        emit TokenRemovedFromWhitelist(_whitelistedTokenAddress);
    }    /**
     * @dev Withdraw ERC20 tokens from the contract.
     * @param _tokenContract Address of the ERC20 token contract.
     * @param _recipient Address to receive the withdrawn tokens.
     * @param _amount Amount of tokens to withdraw.
     */
    function withdrawToken(address _tokenContract, address _recipient, uint256 _amount) external onlyOwner {
        require(_tokenContract != address(0), "Token contract address cannot be zero");
        require(_recipient != address(0), "Recipient address cannot be zero");
        require(_amount > 0, "Amount must be greater than zero");
        ERC20(_tokenContract).transfer(_recipient, _amount);
        emit TokensWithdrawn(_tokenContract, _recipient, _amount);
    }

    /**
     * @dev View the list of packages purchased by a specific project.
     * @param _projectName Name of the project to query.
     * @return string[] Array of package labels purchased by the project.
     */
    function viewProjectPackages(string memory _projectName) external view returns (string[] memory) {
        return individualPackages[_projectName];
    }

    /**
     * @dev Private function to check if a package has already been purchased by a project.
     * @param _package Package to check.
     * @param _projectName Name of the project to check.
     * @return bool True if the package has been purchased, otherwise false.
     */
    function checkForExistingPackage(Package memory _package, string memory _projectName) private view returns (bool) {
        for (uint256 i = 0; i < individualPackages[_projectName].length; i++) {
            if (keccak256(abi.encodePacked(_package.label)) == keccak256(abi.encodePacked(individualPackages[_projectName][i]))) {
                return true;
            }
        }
        return false;
    }

    /**
     * @dev Placeholder function to get the latest Chainlink data feed answer (currently commented out).
     * @param _erc20TokenAddress Address of the ERC20 token for which to get the price.
     * @return uint256 The latest price in base currency.
     */
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
}
