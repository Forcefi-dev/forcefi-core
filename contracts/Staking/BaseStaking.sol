// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@layerzerolabs/solidity-examples/contracts/lzApp/NonblockingLzApp.sol";

/// @title BaseStaking
/// @notice A base contract for staking functionality that handles staking, fee distribution, and user balances.
abstract contract BaseStaking is Ownable, NonblockingLzApp {
    // Counter to track stake IDs
    uint internal _stakeIdCounter;
    uint internal eligibleToReceiveFeeTime;

    // Address where fundraising fees are sent
    address private forcefiFundraisingAddress;

    // Mapping from stake ID to active stake details
    mapping(uint => ActiveStake) public activeStake;
    mapping(address => bool) hasStaked;
    mapping(address => bool) isInvestor;
    mapping(address => uint) public totalStaked;

    // Mapping to track investor token balances by address and token contract
    mapping(address => mapping(address => uint)) public investorTokenBalance;

    // Array to store investor addresses
    uint256[] public investors;

    // Minimum stake amount required to be considered an investor
    uint public investorTreshholdAmount;

    /// @dev Struct representing an active stake made by a user
    /// @param stakeId Unique ID of the stake
    /// @param stakerAddress Address of the user who staked
    /// @param stakeAmount Amount of tokens staked
    /// @param stakeEventTimestamp Timestamp when the stake was made
    /// @param goldNftId Optional NFT ID associated with the stake
    struct ActiveStake {
        uint stakeId;
        address stakerAddress;
        uint stakeAmount;
        uint stakeEventTimestamp;
        uint goldNftId;
    }

    // Events for staking and unstaking
    event CuratorAdded(address indexed stakerAddress);
    event Staked(address indexed stakerAddress, uint amount, uint indexed stakeIdx);
    event Unstaked(address indexed stakerAddress, uint indexed stakeIdx);

    /// @notice Constructor initializes the contract with addresses for fundraising and LayerZero
    /// @param _forcefiFundraisingAddress The address where fundraising fees are sent
    /// @param _lzContractAddress The LayerZero contract address used for cross-chain communication
    constructor(address _forcefiFundraisingAddress, address _lzContractAddress) NonblockingLzApp(_lzContractAddress) Ownable(tx.origin) {
        forcefiFundraisingAddress = _forcefiFundraisingAddress;
    }

    /// @notice Distributes fees to eligible stakers based on their stake and multipliers
    /// @param _feeTokenAddress The address of the ERC20 token used to pay the fees
    /// @param _feeAmount The total amount of fees to distribute
    function receiveFees(address _feeTokenAddress, uint256 _feeAmount) public {
        uint256 totalEligibleStake = 0;
        uint256[] memory eligibleStakes = new uint256[](investors.length);
        address[] memory eligibleFeeReceivers = new address[](investors.length);
        uint256 count = 0;

        uint256 tokensWithMultiplier = 0;

        // Iterate over all investors and calculate their eligible stake for fee distribution
        for (uint256 i = 0; i < investors.length; i++) {
            // Check if the stake is eligible for receiving fees
            if (activeStake[investors[i]].stakeEventTimestamp + eligibleToReceiveFeeTime < block.timestamp) {
                eligibleFeeReceivers[count] = activeStake[investors[i]].stakerAddress;
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

    function setEligabilityTimeToReceiveFees(uint _eligibleToReceiveFeeTime) public onlyOwner {
        eligibleToReceiveFeeTime = _eligibleToReceiveFeeTime;
    }

    /// @notice Allows users to claim their accrued fees
    /// @param _feeTokenAddress The address of the ERC20 token to claim fees in
    function claimFees(address _feeTokenAddress) external {
        uint tokenBalance = investorTokenBalance[msg.sender][_feeTokenAddress];
        IERC20(_feeTokenAddress).transfer(msg.sender, tokenBalance);
        investorTokenBalance[msg.sender][_feeTokenAddress] = 0;
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
    /// @param investorId The ID of the investor to remove
    function removeInvestor(uint investorId) internal {
        uint index = findInvestorIndex(investorId);
        require(index < investors.length, "Investor not found");

        for (uint i = index; i < investors.length - 1; i++) {
            investors[i] = investors[i + 1];
        }
        investors.pop();
    }

    /// @notice Finds the index of an investor in the list
    /// @param investorId The ID of the investor
    /// @return The index of the investor
    function findInvestorIndex(uint investorId) internal view returns (uint) {
        for (uint i = 0; i < investors.length; i++) {
            if (investors[i] == investorId) {
                return i;
            }
        }
        revert("Investor not found");
    }

    /// @notice Returns the list of all investors
    /// @return An array of investor IDs
    function getInvestors() public view returns (uint[] memory) {
        return investors;
    }

    function hasAddressStaked(address _stakerAddress) public view returns(bool){
        return hasStaked[_stakerAddress];
    }
}
