// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title YieldStaking
 * @dev An abstract contract that enables staking of tokens and distributing rewards over time.
 *      Users can stake, unstake, and claim rewards based on their share of the staked amount.
 *      The contract calculates and tracks rewards using an accumulator model.
 */
abstract contract YieldStaking is Ownable {
    using SafeERC20 for ERC20;
    using Cast for uint256;

    // Events for logging key actions
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event Claimed(address indexed user, uint256 amount);
    event RewardsPerTokenUpdated(uint256 accumulated);
    event UserRewardsUpdated(address indexed user, uint256 rewards, uint256 checkpoint);

    /**
     * @dev Tracks rewards per token over time.
     * @notice Accumulated rewards per token are scaled by 1e18 for precision.
     */
    struct RewardsPerToken {
        uint128 accumulated;  // Accumulated rewards per token, scaled by 1e18
        uint128 lastUpdated;  // Last timestamp when rewards per token were updated
    }

    /**
     * @dev Tracks rewards accumulated by individual users.
     */
    struct UserRewards {
        uint128 accumulated;  // Total rewards accumulated by the user
        uint128 checkpoint;   // Last recorded rewards per token for this user
    }

    // State variables
    ERC20 public immutable rewardsToken;  // The token used for rewards distribution
    uint256 public immutable totalLocked; // Total rewards pool locked in the contract

    uint256 public immutable rewardsRate; // Rate of reward distribution per second
    uint256 public immutable rewardsStart; // Timestamp when rewards start
    uint256 public immutable rewardsEnd;   // Timestamp when rewards end
    RewardsPerToken public rewardsPerToken; // Tracks the accumulated rewards per token

    uint256 public totalStaked; // Total amount of tokens currently staked
    mapping(address => uint256) public userStake; // Mapping of user addresses to their staked amount
    mapping(address => UserRewards) public accumulatedRewards; // Mapping of user addresses to their rewards

    bool public rewardTokenLocked; // Indicates if reward tokens have been locked in the contract

    /**
     * @dev Initializes the staking contract.
     * @param rewardsToken_ The ERC20 token used for rewards.
     * @param rewardsStart_ The start timestamp for rewards distribution.
     * @param rewardsEnd_ The end timestamp for rewards distribution.
     * @param totalRewards_ Total amount of rewards to distribute over the period.
     */
    constructor(
        ERC20 rewardsToken_,
        uint256 rewardsStart_,
        uint256 rewardsEnd_,
        uint256 totalRewards_
    ) Ownable(tx.origin) {
        require(address(rewardsToken_) != address(0), "Rewards token cannot be zero address");
        require(rewardsEnd_ > rewardsStart_, "Rewards end must be after rewards start");
        require(totalRewards_ > 0, "Total rewards must be greater than zero");

        rewardsToken = rewardsToken_;
        rewardsStart = rewardsStart_;
        rewardsEnd = rewardsEnd_;
        rewardsRate = totalRewards_ / (rewardsEnd_ - rewardsStart_);
        rewardsPerToken.lastUpdated = rewardsStart_.u128();
        totalLocked = totalRewards_;
    }

    /**
     * @dev Deposits reward tokens into the contract before the rewards program starts.
     *      This function can only be called by the contract owner.
     */
    function depositTreasuryTokens() external onlyOwner {
        require(block.timestamp < rewardsStart, "Can't deposit treasury tokens if staking period has started");
        rewardsToken.safeTransferFrom(msg.sender, address(this), totalLocked);
        rewardTokenLocked = true;
        renounceOwnership(); // Transfers ownership away after deposit
    }

    /**
     * @dev Calculates the new rewards per token based on elapsed time and staking status.
     * @param rewardsPerTokenIn The previous rewards per token state.
     * @return rewardsPerTokenOut The updated rewards per token state.
     */
    function _calculateRewardsPerToken(RewardsPerToken memory rewardsPerTokenIn) internal view returns(RewardsPerToken memory) {
        RewardsPerToken memory rewardsPerTokenOut = RewardsPerToken(rewardsPerTokenIn.accumulated, rewardsPerTokenIn.lastUpdated);
        uint256 totalStaked_ = totalStaked;

        if (block.timestamp < rewardsStart) return rewardsPerTokenOut;

        uint256 updateTime = block.timestamp < rewardsEnd ? block.timestamp : rewardsEnd;
        uint256 elapsed = updateTime - rewardsPerTokenIn.lastUpdated;

        if (elapsed == 0) return rewardsPerTokenOut;
        rewardsPerTokenOut.lastUpdated = updateTime.u128();

        if (totalStaked == 0) return rewardsPerTokenOut;

        rewardsPerTokenOut.accumulated = (rewardsPerTokenIn.accumulated + 1e18 * elapsed * rewardsRate / totalStaked_).u128();
        return rewardsPerTokenOut;
    }

    /**
     * @dev Calculates rewards earned by a user based on staking period.
     * @param stake_ The amount staked by the user.
     * @param earlierCheckpoint The previous rewards checkpoint.
     * @param latterCheckpoint The latest rewards checkpoint.
     * @return The rewards earned.
     */
    function _calculateUserRewards(uint256 stake_, uint256 earlierCheckpoint, uint256 latterCheckpoint) internal pure returns (uint256) {
        return stake_ * (latterCheckpoint - earlierCheckpoint) / 1e18;
    }

    /**
     * @dev Updates the global rewards per token and returns the new state.
     * @return Updated rewards per token state.
     */
    function _updateRewardsPerToken() internal returns (RewardsPerToken memory){
        RewardsPerToken memory rewardsPerTokenIn = rewardsPerToken;
        RewardsPerToken memory rewardsPerTokenOut = _calculateRewardsPerToken(rewardsPerTokenIn);

        if (rewardsPerTokenIn.lastUpdated == rewardsPerTokenOut.lastUpdated) return rewardsPerTokenOut;

        rewardsPerToken = rewardsPerTokenOut;
        emit RewardsPerTokenUpdated(rewardsPerTokenOut.accumulated);

        return rewardsPerTokenOut;
    }

    /**
     * @dev Updates and stores a user's rewards.
     * @param user The user's address.
     * @return Updated user rewards data.
     */
    function _updateUserRewards(address user) internal returns (UserRewards memory) {
        RewardsPerToken memory rewardsPerToken_ = _updateRewardsPerToken();
        UserRewards memory userRewards_ = accumulatedRewards[user];

        if (userRewards_.checkpoint == rewardsPerToken_.lastUpdated) return userRewards_;

        userRewards_.accumulated += _calculateUserRewards(userStake[user], userRewards_.checkpoint, rewardsPerToken_.accumulated).u128();
        userRewards_.checkpoint = rewardsPerToken_.accumulated;

        accumulatedRewards[user] = userRewards_;
        emit UserRewardsUpdated(user, userRewards_.accumulated, userRewards_.checkpoint);

        return userRewards_;
    }

    /**
     * @dev Claims a specific amount of rewards for a user.
     * @param user The address of the user claiming rewards.
     * @param amount The amount to be claimed.
     */
    function _claim(address user, uint256 amount) internal {
        uint256 rewardsAvailable = _updateUserRewards(user).accumulated;
        accumulatedRewards[user].accumulated = (rewardsAvailable - amount).u128();
        rewardsToken.safeTransfer(user, amount);
        emit Claimed(user, amount);
    }

    function stake(uint256 amount) public virtual {
        _stake(msg.sender, amount);
    }

    function unstake(uint256 amount) public virtual {
        _unstake(msg.sender, amount);
    }

    function claim() public virtual returns (uint256) {
        uint256 claimed = _updateUserRewards(msg.sender).accumulated;
        _claim(msg.sender, claimed);
        return claimed;
    }

    function currentRewardsPerToken() public view returns (uint256) {
        return _calculateRewardsPerToken(rewardsPerToken).accumulated;
    }

    function currentUserRewards(address user) public view returns (uint256) {
        UserRewards memory accumulatedRewards_ = accumulatedRewards[user];
        RewardsPerToken memory rewardsPerToken_ = _calculateRewardsPerToken(rewardsPerToken);
        return accumulatedRewards_.accumulated + _calculateUserRewards(userStake[user], accumulatedRewards_.checkpoint, rewardsPerToken_.accumulated);
    }

    function _stake(address user, uint256 token) internal virtual;
    function _unstake(address user, uint256 token) internal virtual;
}

// Utility library for safe casting
library Cast {
    function u128(uint256 x) internal pure returns (uint128 y) {
        require(x <= 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, "Cast overflow");
        y = uint128(x);
    }
}
