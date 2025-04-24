// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "./YieldStaking.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title Erc20YieldStaking
 * @dev Implements ERC20 token staking with a rewards mechanism.
 *      Users can stake tokens, earn rewards over time, and unstake their tokens.
 */
contract Erc20YieldStaking is YieldStaking {
    using SafeERC20 for ERC20;

    ERC20 public immutable stakingToken; // The ERC20 token that users stake
    uint256 public immutable minStakingAmount; // Minimum amount a user can stake
    uint256 public immutable maxStakingAmount; // Maximum total staking amount across all users

    /**
     * @dev Initializes the staking contract.
     * @param stakingToken_ The token that will be staked.
     * @param rewardsToken_ The token used for distributing rewards.
     * @param rewardsStart_ The timestamp when rewards start accruing.
     * @param rewardsEnd_ The timestamp when rewards stop accruing.
     * @param totalRewards_ The total reward pool allocated.
     * @param minStakingAmount_ Minimum staking amount per user.
     * @param maxStakingAmount_ Maximum total staking amount across all users.
     */
    constructor(
        ERC20 stakingToken_,
        ERC20 rewardsToken_,
        uint256 rewardsStart_,
        uint256 rewardsEnd_,
        uint256 totalRewards_,
        uint256 minStakingAmount_,
        uint256 maxStakingAmount_
    ) YieldStaking(rewardsToken_, rewardsStart_, rewardsEnd_, totalRewards_) {
        require(address(stakingToken_) != address(0), "Staking token cannot be zero address");
        require(maxStakingAmount_ > 0, "Max stake must be greater than zero");
        require(minStakingAmount_ < maxStakingAmount_, "Min stake must be less than max stake");
        
        stakingToken = stakingToken_;
        minStakingAmount = minStakingAmount_;
        maxStakingAmount = maxStakingAmount_;
    }

    /**
     * @notice Stake tokens into the contract.
     * @dev Transfers the specified amount of staking tokens from the user to the contract.
     * @param user The address of the user staking tokens.
     * @param amount The amount of tokens to stake.
     */
    function _stake(address user, uint256 amount) internal override {
        require(rewardTokenLocked, "Reward token has not been locked yet");
        require(amount >= minStakingAmount, "Stake amount is less than minimum");
        require(amount + totalStaked <= maxStakingAmount, "The maximum staking amount has been reached for all holders");

        _updateUserRewards(user);
        totalStaked += amount;
        userStake[user] += amount;

        stakingToken.safeTransferFrom(user, address(this), amount);
        emit Staked(user, amount);
    }

    /**
     * @notice Unstake tokens from the contract.
     * @dev Transfers the specified amount of staking tokens from the contract back to the user.
     * @param user The address of the user unstaking tokens.
     * @param amount The amount of tokens to unstake.
     */
    function _unstake(address user, uint256 amount) internal override {
        require(
            userStake[user] - amount >= minStakingAmount || userStake[user] == amount,
            "Either unstake the whole amount or leave more than the minimum stake amount"
        );

        _updateUserRewards(user);
        totalStaked -= amount;
        userStake[user] -= amount;

        stakingToken.safeTransfer(user, amount);
        emit Unstaked(user, amount);
    }
}
