// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "@layerzerolabs/solidity-examples/contracts/lzApp/NonblockingLzApp.sol";

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
contract ForcefiPackage is Ownable, NonblockingLzApp {
    // Address of the LayerZero contract used for cross-chain operations
    address private lzContractAddress;

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

    /**
     * @dev Constructor to initialize the contract with the LayerZero contract address and default packages.
     * @param _lzContractAddress Address of the LayerZero contract.
     */
    constructor(address _lzContractAddress) Ownable(tx.origin) NonblockingLzApp(_lzContractAddress){
        lzContractAddress = _lzContractAddress;
        addPackage("Explorer", 750, false, 5, false);      // Adding default "Explorer" package
        addPackage("Accelerator", 2000, false, 5, true);   // Adding default "Accelerator" package
    }

    function _nonblockingLzReceive(uint16, bytes memory, uint64, bytes memory _payload) internal override {
        (address _tokenOwner, string memory _projectName) = abi.decode(_payload, (address, string));
        _mintPackageToken(_tokenOwner, _projectName);
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
        packageToUpdate.amount = newAmount;
        packageToUpdate.isCustom = newIsCustom;
        packageToUpdate.referralFee = newReferralFee;
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
     * @dev Function to bridge a creation token to another blockchain (currently commented out).
     * @param _destChainId Destination chain ID.
     * @param _projectName Name of the project associated with the token.
     * @param _tokenOwner Address of the token owner.
     * @param gasForDestinationLzReceive Gas required for destination LayerZero receive.
     */
    function bridgeToken(uint16 _destChainId, string memory _projectName, address _tokenOwner, uint gasForDestinationLzReceive) public payable {
        require(creationTokens[msg.sender][_projectName], "No token to bridge");
        bytes memory payload = abi.encode(_tokenOwner, _projectName);
        uint16 version = 1;
        bytes memory adapterParams = abi.encodePacked(version, gasForDestinationLzReceive);
        _lzSend(_destChainId, payload, payable(tx.origin), address(0x0), adapterParams);
    }

    /**
     * @dev Mint a creation token by the contract owner.
     * @param _tokenHolder Address of the token holder.
     * @param _projectName Name of the project associated with the token.
     */
    function ownerMintToken(address _tokenHolder, string memory _projectName) public onlyOwner {
        _mintPackageToken(_tokenHolder, _projectName);
    }

    /**
     * @dev Whitelist an ERC20 token for investment.
     * @param _whitelistedTokenAddress Address of the ERC20 token to whitelist.
     * @param _dataFeedAddress Address of the Chainlink data feed (currently commented out).
     */
    function whitelistTokenForInvestment(address _whitelistedTokenAddress, address _dataFeedAddress) external onlyOwner {
        whitelistedToken[_whitelistedTokenAddress] = true;
        dataFeeds[_whitelistedTokenAddress] = AggregatorV3Interface(_dataFeedAddress);
    }

    /**
     * @dev Remove an ERC20 token from the whitelist.
     * @param _whitelistedTokenAddress Address of the ERC20 token to remove.
     */
    function removeWhitelistInvestmentToken(address _whitelistedTokenAddress) external onlyOwner {
        whitelistedToken[_whitelistedTokenAddress] = false;
    }

    /**
     * @dev Withdraw ERC20 tokens from the contract.
     * @param _tokenContract Address of the ERC20 token contract.
     * @param _recipient Address to receive the withdrawn tokens.
     * @param _amount Amount of tokens to withdraw.
     */
    function withdrawToken(address _tokenContract, address _recipient, uint256 _amount) external onlyOwner {
        ERC20(_tokenContract).transfer(_recipient, _amount);
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
