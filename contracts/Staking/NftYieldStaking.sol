// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IUniswapV3PositionManager {
    function positions(uint256 tokenId) external view returns (
        uint96 nonce,
        address operator,
        address token0,
        address token1,
        uint24 fee,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity,
        uint256 feeGrowthInside0LastX128,
        uint256 feeGrowthInside1LastX128,
        uint128 tokensOwed0,
        uint128 tokensOwed1
    );
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
}

/// @title Erc20YieldStaking
/// @notice A permissionless staking contract for a single rewards program.
/// @dev Rewards are distributed linearly over a fixed period of time, with a fixed total rewards pool.
/// The rewards distribution is proportional to the amount staked by each user. Rewards tokens must
/// be locked in the contract before the staking period begins.
contract NftYieldStaking is Ownable{
    using SafeERC20 for ERC20;
    using Cast for uint256;

    // Events for logging key actions
    event Staked(address user, uint256 amount);
    event Unstaked(address user, uint256 amount);
    event Claimed(address user, uint256 amount);
    event RewardsPerTokenUpdated(uint256 accumulated);
    event UserRewardsUpdated(address user, uint256 rewards, uint256 checkpoint);

    /// @notice Tracks rewards per token over time.
    /// @dev Accumulated rewards per token are scaled by 1e18 for precision.
    struct RewardsPerToken {
        uint128 accumulated;                                        // Accumulated rewards per token for the interval, scaled up by 1e18
        uint128 lastUpdated;                                        // Last time the rewards per token accumulator was updated
    }

    /// @notice Tracks rewards accumulated by individual users.
    struct UserRewards {
        uint128 accumulated;                                        // Accumulated rewards for the user until the checkpoint
        uint128 checkpoint;                                         // RewardsPerToken the last time the user rewards were updated
    }

    // State variables
    IUniswapV3PositionManager public immutable positionManager;

    ERC20 public immutable lpStakingToken1; // Token that users stake
    ERC20 public immutable lpStakingToken2; // Token that users stake
    ERC20 public immutable rewardsToken; // Token distributed as rewards
    uint256 public immutable totalLocked; // Total rewards pool locked in the contract
    uint256 public immutable rewardsRate; // Rewards rate per second
    uint256 public immutable rewardsStart; // Start time for rewards distribution
    uint256 public immutable rewardsEnd;   // End time for rewards distribution
    RewardsPerToken public rewardsPerToken; // Tracks rewards per token over time

    uint256 public totalStaked; // Total amount currently staked
    mapping(address => uint256) public userStake; // Mapping of user address to staked amount
    mapping(address => UserRewards) public accumulatedRewards; // Mapping of user address to their rewards data
    mapping(uint256 => address) public nftOwner; // Mapping of user address to their rewards data

    bool public rewardTokenLocked; // Indicates whether rewards tokens are locked in the contract

    /// @dev Initializes the contract with staking and rewards tokens, staking limits, and rewards configuration.
    /// @param lpStakingToken1_ The token to be staked.
    /// @param lpStakingToken2_ The token to be staked.
    /// @param rewardsToken_ The token distributed as rewards.
    /// @param rewardsStart_ Start time for the rewards program.
    /// @param rewardsEnd_ End time for the rewards program.
    /// @param totalRewards_ Total rewards to be distributed over the program's duration.
    constructor(
        ERC20 lpStakingToken1_,
        ERC20 lpStakingToken2_,
        ERC20 rewardsToken_,
        uint256 rewardsStart_,
        uint256 rewardsEnd_,
        uint256 totalRewards_,
        IUniswapV3PositionManager _positionManager
    ) Ownable(tx.origin) {
        lpStakingToken1 = lpStakingToken1_;
        lpStakingToken2 = lpStakingToken2_;
        rewardsToken = rewardsToken_;
        rewardsStart = rewardsStart_;
        rewardsEnd = rewardsEnd_;
        rewardsRate = totalRewards_ / (rewardsEnd_ - rewardsStart_);
        rewardsPerToken.lastUpdated = rewardsStart_.u128();
        totalLocked = totalRewards_;

        positionManager = _positionManager;
    }

    function depositTreasuryTokens() external onlyOwner {
        require(block.timestamp < rewardsStart, "Can't deposit treasury tokens if staking period has started");
        rewardsToken.safeTransferFrom(msg.sender, address(this), totalLocked);
        rewardTokenLocked = true;
        renounceOwnership();
    }

    /// @notice Update the rewards per token accumulator according to the rate, the time elapsed since the last update, and the current total staked amount.
    function _calculateRewardsPerToken(RewardsPerToken memory rewardsPerTokenIn) internal view returns(RewardsPerToken memory) {
        RewardsPerToken memory rewardsPerTokenOut = RewardsPerToken(rewardsPerTokenIn.accumulated, rewardsPerTokenIn.lastUpdated);
        uint256 totalStaked_ = totalStaked;

        // No changes if the program hasn't started
        if (block.timestamp < rewardsStart) return rewardsPerTokenOut;

        // Stop accumulating at the end of the rewards interval
        uint256 updateTime = block.timestamp < rewardsEnd ? block.timestamp : rewardsEnd;
        uint256 elapsed = updateTime - rewardsPerTokenIn.lastUpdated;

        // No changes if no time has passed
        if (elapsed == 0) return rewardsPerTokenOut;
        rewardsPerTokenOut.lastUpdated = updateTime.u128();

        // If there are no stakers we just change the last update time, the rewards for intervals without stakers are not accumulated
        if (totalStaked == 0) return rewardsPerTokenOut;

        // Calculate and update the new value of the accumulator.
        rewardsPerTokenOut.accumulated = (rewardsPerTokenIn.accumulated + 1e18 * elapsed * rewardsRate / totalStaked_).u128(); // The rewards per token are scaled up for precision
        return rewardsPerTokenOut;
    }

    /// @notice Calculate the rewards accumulated by a stake between two checkpoints.
    function _calculateUserRewards(uint256 stake_, uint256 earlierCheckpoint, uint256 latterCheckpoint) internal pure returns (uint256) {
        return stake_ * (latterCheckpoint - earlierCheckpoint) / 1e18; // We must scale down the rewards by the precision factor
    }

    /// @notice Update and return the rewards per token accumulator according to the rate, the time elapsed since the last update, and the current total staked amount.
    function _updateRewardsPerToken() internal returns (RewardsPerToken memory){
        RewardsPerToken memory rewardsPerTokenIn = rewardsPerToken;
        RewardsPerToken memory rewardsPerTokenOut = _calculateRewardsPerToken(rewardsPerTokenIn);

        // We skip the storage changes if already updated in the same block, or if the program has ended and was updated at the end
        if (rewardsPerTokenIn.lastUpdated == rewardsPerTokenOut.lastUpdated) return rewardsPerTokenOut;

        rewardsPerToken = rewardsPerTokenOut;
        emit RewardsPerTokenUpdated(rewardsPerTokenOut.accumulated);

        return rewardsPerTokenOut;
    }

    /// @notice Calculate and store current rewards for an user. Checkpoint the rewardsPerToken value with the user.
    function _updateUserRewards(address user) internal returns (UserRewards memory) {
        RewardsPerToken memory rewardsPerToken_ = _updateRewardsPerToken();
        UserRewards memory userRewards_ = accumulatedRewards[user];

        // We skip the storage changes if already updated in the same block
        if (userRewards_.checkpoint == rewardsPerToken_.lastUpdated) return userRewards_;

        // Calculate and update the new value user reserves.
        userRewards_.accumulated += _calculateUserRewards(userStake[user], userRewards_.checkpoint, rewardsPerToken_.accumulated).u128();
        userRewards_.checkpoint = rewardsPerToken_.accumulated;

        accumulatedRewards[user] = userRewards_;
        emit UserRewardsUpdated(user, userRewards_.accumulated, userRewards_.checkpoint);

        return userRewards_;
    }

    function _stake(address user, uint256 tokenId) internal {
        (, , address token0, address token1, , , , uint128 liquidity, , , ,) = positionManager.positions(tokenId);
        require(liquidity > 0, "No liquidity in NFT");
        require(token0 == address(lpStakingToken1) || token1 == address(lpStakingToken1), "Invalid lpStakingToken1 token");
        require(token0 == address(lpStakingToken2) || token1 == address(lpStakingToken2), "Invalid lpStakingToken2 token");

        _updateUserRewards(user);
        totalStaked += liquidity;
        userStake[user] += liquidity;
        nftOwner[tokenId] = user;

        positionManager.safeTransferFrom(user, address(this), tokenId);

        emit Staked(user, tokenId);
    }


    /// @notice Unstake tokens.
    function _unstake(address user, uint256 tokenId) internal
    {
        require (user == nftOwner[tokenId], "Only initial owner of NFT token can unstake");

        (, , , , , , , uint128 liquidity, , , ,) = positionManager.positions(tokenId);
        _updateUserRewards(user);
        totalStaked -= liquidity;
        userStake[user] -= liquidity;

        positionManager.safeTransferFrom(address(this), user, tokenId);

        emit Unstaked(user, liquidity);
    }

    /// @notice Claim rewards.
    function _claim(address user, uint256 amount) internal
    {
        uint256 rewardsAvailable = _updateUserRewards(msg.sender).accumulated;

        // This line would panic if the user doesn't have enough rewards accumulated
        accumulatedRewards[user].accumulated = (rewardsAvailable - amount).u128();

        // This line would panic if the contract doesn't have enough rewards tokens
        rewardsToken.safeTransfer(user, amount);
        emit Claimed(user, amount);
    }


    /// @notice Stake tokens.
    function stake(uint256 tokenId) public virtual
    {
        _stake(msg.sender, tokenId);
    }


    /// @notice Unstake tokens.
    function unstake(uint256 tokenId) public virtual
    {
        _unstake(msg.sender, tokenId);
    }

    /// @notice Claim all rewards for the caller.
    function claim() public virtual returns (uint256)
    {
        uint256 claimed = _updateUserRewards(msg.sender).accumulated;
        _claim(msg.sender, claimed);
        return claimed;
    }

    /// @notice Calculate and return current rewards per token.
    function currentRewardsPerToken() public view returns (uint256) {
        return _calculateRewardsPerToken(rewardsPerToken).accumulated;
    }

    /// @notice Calculate and return current rewards for a user.
    /// @dev This repeats the logic used on transactions, but doesn't update the storage.
    function currentUserRewards(address user) public view returns (uint256) {
        UserRewards memory accumulatedRewards_ = accumulatedRewards[user];
        RewardsPerToken memory rewardsPerToken_ = _calculateRewardsPerToken(rewardsPerToken);
        return accumulatedRewards_.accumulated + _calculateUserRewards(userStake[user], accumulatedRewards_.checkpoint, rewardsPerToken_.accumulated);
    }
}

// The library `Cast` is used for safe uint128 casting.
library Cast {
    function u128(uint256 x) internal pure returns (uint128 y) {
        require(x <= 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, "Cast overflow"); // Max value of uint128
        y = uint128(x);
    }
}

