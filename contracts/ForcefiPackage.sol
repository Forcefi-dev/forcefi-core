// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "https://github.com/LayerZero-Labs/solidity-examples/blob/main/contracts/lzApp/NonblockingLzApp.sol";

interface ILzContract {
    function send(address, string memory) external;
}

interface IForcefiPackage {
    function importCreationToken(address, string memory) external view returns(bool);
}

contract ForcefiPackage is Ownable {
    address private lzContractAddress;
    mapping(address => AggregatorV3Interface) dataFeeds;

    struct Package {
        string label;
        uint256 amount;
        bool isCustom;
        uint256 referralFee;
        bool benefitsEnabled;
    }

    Package [] public packages;

    mapping(address => bool) public whitelistedToken;
    mapping(string => string[]) individualPackages;
    mapping(string => uint256) public amountInvestedByProject;
    mapping(address => mapping(string => bool)) private creationTokens;

    event PackageBought (string projectName, string tier, address indexed buyer);

    constructor(address _lzContractAddress) {
        lzContractAddress = _lzContractAddress;
        addPackage("Explorer", 750, false, 5, false);
        addPackage("Accelerator", 2000, false, 5, true);
    }

    function _nonblockingLzReceive(uint16, bytes memory, uint64, bytes memory _payload) internal override {
        (address _tokenOwner, string memory _projectName) = abi.decode(_payload, (address, string));
        _mintPackageToken(_tokenOwner, _projectName);
    }

    function trustAddress(uint16 _destChainId, address _otherContract) public onlyOwner {
        trustedRemoteLookup[_destChainId] = abi.encodePacked(_otherContract, address(this));
    }

    function addPackage(string memory _label, uint256 _amount, bool _isCustom, uint256 _referralFee, bool _benefitsEnabled) public onlyOwner{
        Package memory newTier = Package({
        label: _label,
        amount: _amount,
        isCustom: _isCustom,
        referralFee: _referralFee,
        benefitsEnabled: _benefitsEnabled
        });

        packages.push(newTier);
    }

    function updatePackage(string memory _label, uint256 newAmount, bool newIsCustom, uint256 newReferralFee) external onlyOwner{
        Package storage packageToUpdate = getPackageByLabel(_label);
        packageToUpdate.amount = newAmount;
        packageToUpdate.isCustom = newIsCustom;
        packageToUpdate.referralFee = newReferralFee;
    }

    function getPackageByLabel(string memory label) private view returns (Package storage) {
        for (uint256 i = 0; i < packages.length; i++) {
            if (keccak256(abi.encodePacked(packages[i].label)) == keccak256(abi.encodePacked(label))) {
                return packages[i];
            }
        }

        revert("Package not found");
    }

    function buyPackage(string memory _projectName, string memory _packageLabel, address _erc20TokenAddress, address _referralAddress) external {
        require(whitelistedToken[_erc20TokenAddress], "Not whitelisted investment token");
        Package memory package = getPackageByLabel(_packageLabel);
        require(!checkForExistingPackage(package, _projectName), "Project has already bought this package");
        uint256 amountToPay = package.amount;
        if (!package.isCustom){
            amountToPay = package.amount - amountInvestedByProject[_projectName];
            amountInvestedByProject[_projectName] += amountToPay;
            // Mint token that can be used for free token creation / fundraising / vesting
            if(package.benefitsEnabled){
                _mintPackageToken(msg.sender, _projectName);
            }
        }

        uint256 finalAmountToPay = uint256(getChainlinkDataFeedLatestAnswer(_erc20TokenAddress)) * amountToPay;

        uint256 referralFee = 0;
        if (_referralAddress != address(0)){
            referralFee = finalAmountToPay * package.referralFee / 100;
            ERC20(_erc20TokenAddress).transferFrom(msg.sender, _referralAddress, referralFee);
        }

        uint256 packagePaymentCost = finalAmountToPay - referralFee;

        ERC20(_erc20TokenAddress).transferFrom(msg.sender, address(this), packagePaymentCost);

        individualPackages[_projectName].push(_packageLabel);
        emit PackageBought(_projectName, _packageLabel, msg.sender);
    }

    function _mintPackageToken(address _tokenOwner, string memory _projectName) private {
        creationTokens[_tokenOwner][_projectName] = true;
    }

    function hasCreationToken(address _tokenOwner, string memory _projectName) external view returns(bool){
        return creationTokens[_tokenOwner][_projectName];
    }

    function bridgeToken(uint16 _destChainId, string memory _projectName, address _tokenOwner, uint gasForDestinationLzReceive) public payable {
        require(creationTokens[msg.sender][_projectName], "No token to bridge");
        bytes memory payload = abi.encode(_tokenOwner, _projectName);
        uint16 version = 1;
        bytes memory adapterParams = abi.encodePacked(version, gasForDestinationLzReceive);
        _lzSend(_destChainId, payload, payable(tx.origin), address(0x0), adapterParams, msg.value);
    }

    // Mint token by owner
    function ownerMintToken(address _tokenHolder, string memory _projectName) public onlyOwner{
        _mintPackageToken(_tokenHolder, _projectName);
    }

    function whitelistTokenForInvestment(address _whitelistedTokenAddress, address _dataFeedAddress) external onlyOwner {
        whitelistedToken[_whitelistedTokenAddress] = true;
        dataFeeds[_whitelistedTokenAddress] = AggregatorV3Interface(_dataFeedAddress);
    }

    function removeWhitelistInvestmentToken(address _whitelistedTokenAddress) external onlyOwner {
        whitelistedToken[_whitelistedTokenAddress] = false;
    }

    function withdrawToken(address _tokenContract, address _recipient, uint256 _amount) external onlyOwner {
        ERC20(_tokenContract).transfer(_recipient, _amount);
    }

    function viewProjectPackages(string memory _projectName) external view returns (string[] memory) {
        return individualPackages[_projectName];
    }

    function checkForExistingPackage(Package memory _package, string memory _projectName) private view returns (bool) {
        for (uint256 i = 0; i < individualPackages[_projectName].length; i++) {
            if (keccak256(abi.encodePacked(_package.label)) == keccak256(abi.encodePacked(individualPackages[_projectName][i]))) {
                return true;
            }
        }
        return false;
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

}
