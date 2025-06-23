// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { OApp, MessagingFee, Origin } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OApp.sol";
import { MessagingReceipt } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OAppSender.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title BaseStaking
/// @notice A base contract for staking functionality that handles staking, fee distribution, and user balances.
abstract contract BaseStaking is Ownable, OApp, ReentrancyGuard {
    // Counter to track stake IDs
    uint internal _stakeIdCounter;
    uint internal eligibleToReceiveFeeTime;

    // Address where fundraising fees are sent
    address private forcefiFundraisingAddress;

    // Mapping from stake ID to active stake details
    mapping(address => ActiveStake) public activeStake;
    mapping(address => bool) hasStaked;

    // Mapping to track investor token balances by address and token contract
    mapping(address => mapping(address => uint)) public investorTokenBalance;

    // Array to store investor addresses
    address[] public investors;

    // Minimum stake amount required to be considered an investor
    uint public investorTreshholdAmount;

    /// @dev Struct representing an active stake made by a user
    /// @param stakeId Unique ID of the stake
    /// @param stakerAddress Address of the user who staked
    /// @param stakeAmount Amount of tokens staked
    /// @param stakeEventTimestamp Timestamp when the stake was made
    /// @param silverNftId Optional NFT ID associated with the stake
    /// @param goldNftId Optional NFT ID associated with the stake
    struct ActiveStake {
        uint stakeId;
        uint stakeAmount;
        uint stakeEventTimestamp;
        uint silverNftId;
        uint goldNftId;
    }

    // Events for staking and unstaking
    event CuratorAdded(address indexed stakerAddress);
    event Staked(address indexed stakerAddress, uint amount, uint indexed stakeIdx);
    event Unstaked(address indexed stakerAddress, uint indexed stakeIdx);

    /// @notice Constructor initializes the contract with addresses for fundraising and LayerZero
    /// @param _forcefiFundraisingAddress The address where fundraising fees are sent
    constructor(address _forcefiFundraisingAddress, address _endpoint, address _delegate) OApp(_endpoint, _delegate) Ownable(_delegate) {
        forcefiFundraisingAddress = _forcefiFundraisingAddress;
    }

    /// @notice Distributes fees to eligible stakers based on their stake and multipliers
    /// @param _feeTokenAddress The address of the ERC20 token used to pay the fees
    /// @param _feeAmount The total amount of fees to distribute
    function receiveFees(address _feeTokenAddress, uint256 _feeAmount) public {
        require(msg.sender == forcefiFundraisingAddress, "Not fundraising address");
        address[] memory eligibleFeeReceivers = new address[](investors.length);
        uint256 count = 0;

        // Iterate over all investors and calculate their eligible stake for fee distribution
        for (uint256 i = 0; i < investors.length; i++) {
            // Check if the stake is eligible for receiving fees
            if (activeStake[investors[i]].stakeEventTimestamp + eligibleToReceiveFeeTime < block.timestamp) {
                eligibleFeeReceivers[count] = investors[i];
                count++;
            }
        }

        // Distribute fees based on calculated multipliers
        if (count > 0) {
            IERC20(_feeTokenAddress).transferFrom(forcefiFundraisingAddress, address(this), _feeAmount);
            uint256 feeShare = _feeAmount / count;
            for (uint256 j = 0; j < count; j++) {
                investorTokenBalance[eligibleFeeReceivers[j]][_feeTokenAddress] += feeShare;
            }
        }
        // TODO: Send to treasury
        else {

        }
    }

    /// @notice Distributes native currency (ETH) fees to eligible stakers
    function receiveNativeCurrencyFees() external payable {
        require(msg.sender == forcefiFundraisingAddress, "Not fundraising address");
        require(msg.value > 0, "No fees to distribute");
        
        address[] memory eligibleFeeReceivers = new address[](investors.length);
        uint256 count = 0;

        // Iterate over all investors and calculate their eligible stake for fee distribution
        for (uint256 i = 0; i < investors.length; i++) {
            // Check if the stake is eligible for receiving fees
            if (activeStake[investors[i]].stakeEventTimestamp + eligibleToReceiveFeeTime < block.timestamp) {
                eligibleFeeReceivers[count] = investors[i];
                count++;
            }
        }

        // Distribute fees based on calculated multipliers
        if (count > 0) {
            uint256 feeShare = msg.value / count;
            // Use address(0) to represent native currency
            address nativeCurrency = address(0);
            for (uint256 j = 0; j < count; j++) {
                investorTokenBalance[eligibleFeeReceivers[j]][nativeCurrency] += feeShare;
            }
        }
        // TODO: Send to treasury if no eligible receivers
        else {
            // For now, the contract holds the ETH if no eligible receivers
            // This should be modified to send to treasury in the future
        }
    }

    function setEligabilityTimeToReceiveFees(uint _eligibleToReceiveFeeTime) public onlyOwner {
        eligibleToReceiveFeeTime = _eligibleToReceiveFeeTime;
    }    /// @notice Allows users to claim their accrued fees
    /// @param _feeTokenAddress The address of the ERC20 token to claim fees in (use address(0) for native currency)
    function claimFees(address _feeTokenAddress) external nonReentrant{
        uint tokenBalance = investorTokenBalance[msg.sender][_feeTokenAddress];
        require(tokenBalance > 0, "No fees to claim");
        
        investorTokenBalance[msg.sender][_feeTokenAddress] = 0;
        
        if (_feeTokenAddress == address(0)) {
            // Handle native currency (ETH)
            payable(msg.sender).transfer(tokenBalance);
        } else {
            // Handle ERC20 tokens
            IERC20(_feeTokenAddress).transfer(msg.sender, tokenBalance);
        }
    }

    /// @notice Returns the balance of a specific token for a given investor
    /// @param _investor The address of the investor
    /// @param _token The address of the ERC20 token
    /// @return The token balance of the investor
    function getBalance(address _investor, address _token) public view returns (uint) {
        return investorTokenBalance[_investor][_token];
    }

    /// @notice Sets the minimum threshold amount for investors
    /// @param _investorTreshholdAmount The new threshold amount
    function setInvestorTreshholdAmount(uint _investorTreshholdAmount) external onlyOwner {
        investorTreshholdAmount = _investorTreshholdAmount;
    }

    /// @notice Removes an investor from the list of active investors
    function removeInvestor(address investorAddress) internal {
        uint index = findInvestorIndex(investorAddress);
        require(index < investors.length, "Investor not found");

        for (uint i = index; i < investors.length - 1; i++) {
            investors[i] = investors[i + 1];
        }
        investors.pop();
    }

    /// @notice Finds the index of an investor in the list
    function findInvestorIndex(address investorAddress) internal view returns (uint) {
        for (uint i = 0; i < investors.length; i++) {
            if (investors[i] == investorAddress) {
                return i;
            }
        }
        revert("Investor not found");
    }

    /// @notice Returns the list of all investors
    /// @return An array of investor IDs
    function getInvestors() public view returns (address[] memory) {
        return investors;
    }

    function hasAddressStaked(address _stakerAddress) public view returns(bool){
        return hasStaked[_stakerAddress];
    }
}
