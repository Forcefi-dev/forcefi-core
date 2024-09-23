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

    // Struct to define fee multipliers based on stake duration
    FeeMultiplier public feeMultiplier;

    // Address where fundraising fees are sent
    address private forcefiFundraisingAddress;

    // Mapping from stake ID to active stake details
    mapping(uint => ActiveStake) public activeStake;

    // Mapping to track investor token balances by address and token contract
    mapping(address => mapping(address => uint)) public investorTokenBalance;

    // Mapping to track stake IDs for each user
    mapping(address => uint[]) public userStakes;

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

    /// @dev Struct representing fee multipliers based on staking time thresholds
    /// @param eligibleToReceiveFee Minimum time to be eligible for fees
    /// @param earlyUnstakePercent Penalty percentage for early unstaking
    /// @param beginnerFeeThreshold Time threshold for beginner fee multiplier
    /// @param intermediateFeeThreshold Time threshold for intermediate fee multiplier
    /// @param maximumFeeThreshold Time threshold for maximum fee multiplier
    /// @param beginnerMultiplier Multiplier applied for beginner stakers
    /// @param intermediateMultiplier Multiplier applied for intermediate stakers
    /// @param maximumMultiplier Multiplier applied for maximum duration stakers
    struct FeeMultiplier {
        uint256 eligibleToReceiveFee;
        uint256 earlyUnstakePercent;
        uint256 beginnerFeeThreshold;
        uint256 intermediateFeeThreshold;
        uint256 maximumFeeThreshold;
        uint256 beginnerMultiplier;
        uint256 intermediateMultiplier;
        uint256 maximumMultiplier;
    }

    // Events for staking and unstaking
    event Staked(address indexed stakerAddress, uint amount, uint indexed stakeIdx);
    event Unstaked(address indexed stakerAddress, uint indexed stakeIdx);

    /// @notice Constructor initializes the contract with addresses for fundraising and LayerZero
    /// @param _forcefiFundraisingAddress The address where fundraising fees are sent
    /// @param _lzContractAddress The LayerZero contract address used for cross-chain communication
    constructor(address _forcefiFundraisingAddress, address _lzContractAddress) NonblockingLzApp(_lzContractAddress) Ownable(tx.origin) {
        forcefiFundraisingAddress = _forcefiFundraisingAddress;

        // Initializing fee multipliers based on a time-based threshold system
        feeMultiplier = FeeMultiplier(
            2629800,
            0,
            2629800 * 3,
            2629800 * 6,
            2629800 * 9,
            10,
            20,
            30
        );
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
            if (activeStake[investors[i]].stakeEventTimestamp + feeMultiplier.eligibleToReceiveFee < block.timestamp) {
                uint256 stakingTime = block.timestamp - activeStake[investors[i]].stakeEventTimestamp;
                uint256 multiplier = getMultiplier(stakingTime);

                uint256 activeStakeMultiplied = multiplier * activeStake[investors[i]].stakeAmount;
                tokensWithMultiplier += activeStakeMultiplied;

                eligibleFeeReceivers[count] = activeStake[investors[i]].stakerAddress;
                eligibleStakes[count] = activeStakeMultiplied;
                count++;
            }
        }

        // Distribute fees based on calculated multipliers
        if (count > 0) {
            IERC20(_feeTokenAddress).transferFrom(forcefiFundraisingAddress, address(this), _feeAmount);

            for (uint256 j = 0; j < count; j++) {
                uint256 stakeAmount = eligibleStakes[j];
                uint256 feeShare = (_feeAmount * stakeAmount) / tokensWithMultiplier;

                investorTokenBalance[eligibleFeeReceivers[j]][_feeTokenAddress] += feeShare;
            }
        }
    }

    /// @notice Updates the fee multiplier values used to calculate staking rewards
    /// @param _eligibleToReceiveFee Time required to be eligible for fee rewards
    /// @param _earlyUnstakePercent Penalty for unstaking early
    /// @param _beginnerFeeThreshold Time threshold for beginner multiplier
    /// @param _intermediateFeeThreshold Time threshold for intermediate multiplier
    /// @param _maximumFeeThreshold Time threshold for maximum multiplier
    /// @param _beginnerMultiplier Beginner multiplier percentage
    /// @param _intermediateMultiplier Intermediate multiplier percentage
    /// @param _maximumMultiplier Maximum multiplier percentage
    function setFeeMultiplier(
        uint _eligibleToReceiveFee,
        uint _earlyUnstakePercent,
        uint _beginnerFeeThreshold,
        uint _intermediateFeeThreshold,
        uint _maximumFeeThreshold,
        uint _beginnerMultiplier,
        uint _intermediateMultiplier,
        uint _maximumMultiplier
    ) public onlyOwner {
        feeMultiplier = FeeMultiplier(
            _eligibleToReceiveFee,
            _earlyUnstakePercent,
            _beginnerFeeThreshold,
            _intermediateFeeThreshold,
            _maximumFeeThreshold,
            _beginnerMultiplier,
            _intermediateMultiplier,
            _maximumMultiplier
        );
    }

    /// @notice Internal function to determine the appropriate multiplier based on staking time
    /// @param stakingTime The duration for which tokens have been staked
    /// @return The multiplier value based on the staking time
    function getMultiplier(uint256 stakingTime) internal view returns (uint256) {
        if (stakingTime >= feeMultiplier.maximumFeeThreshold) {
            return 100 + feeMultiplier.maximumMultiplier;
        } else if (stakingTime >= feeMultiplier.intermediateFeeThreshold) {
            return 100 + feeMultiplier.intermediateMultiplier;
        } else if (stakingTime >= feeMultiplier.beginnerFeeThreshold) {
            return 100 + feeMultiplier.beginnerMultiplier;
        } else {
            return 100;
        }
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

    /// @notice Helper function to remove a stake from a user's list of stakes
    /// @param _user The address of the user
    /// @param _stakeId The ID of the stake to remove
    function removeStakeFromUser(address _user, uint _stakeId) internal {
        uint[] storage stakes = userStakes[_user];
        for (uint i = 0; i < stakes.length; i++) {
            if (stakes[i] == _stakeId) {
                stakes[i] = stakes[stakes.length - 1];
                stakes.pop();
                break;
            }
        }
    }

    /// @notice Checks if a user has any active stakes
    /// @param _stakerAddress The address of the staker
    /// @return A boolean indicating whether the user has an active stake
    function hasStaked(address _stakerAddress) public view returns (bool) {
        uint[] memory stakes = userStakes[_stakerAddress];

        for (uint i = 0; i < stakes.length; i++) {
            uint stakeId = stakes[i];
            if (activeStake[stakeId].stakeAmount > 0) {
                return true;
            }
        }
        return false;
    }
}
