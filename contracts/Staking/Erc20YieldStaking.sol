// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "./YieldStaking.sol";

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Erc20YieldStaking is YieldStaking{

    using SafeERC20 for ERC20;

    ERC20 public immutable stakingToken; // Token that users stake

    uint256 public immutable minStakingAmount; // Minimum amount a user can stake
    uint256 public immutable maxStakingAmount; // Maximum total staking amount across all users

    /// @param minStakingAmount_ Minimum staking amount for users.
    /// @param maxStakingAmount_ Maximum total staking amount across all users.
    constructor(ERC20 stakingToken_,
        ERC20 rewardsToken_,
        uint256 rewardsStart_,
        uint256 rewardsEnd_,
        uint256 totalRewards_,
        uint256 minStakingAmount_,
        uint256 maxStakingAmount_)
    YieldStaking(rewardsToken_, rewardsStart_, rewardsEnd_, totalRewards_) {
        stakingToken = stakingToken_;
        minStakingAmount = minStakingAmount_;
        maxStakingAmount = maxStakingAmount_;
    }

    /// @notice Stake tokens.
    function _stake(address user, uint256 amount) internal override
    {
        require(rewardTokenLocked, "Reward token has not been locked yet");
        require(amount >= minStakingAmount, "Stake amount is less than minimum");
        require(amount + totalStaked <= maxStakingAmount, "The maximum staking amount has been reached for all holders");
        _updateUserRewards(user);
        totalStaked += amount;
        userStake[user] += amount;
        stakingToken.safeTransferFrom(user, address(this), amount);
        emit Staked(user, amount);
    }

    /// @notice Unstake tokens.
    function _unstake(address user, uint256 amount) internal override
    {
        require(userStake[user] - amount >= minStakingAmount || userStake[user] == amount, "Either unstake whole stake amount, or the amount left has to be more than minimal stake amount");
        _updateUserRewards(user);
        totalStaked -= amount;
        userStake[user] -= amount;
        stakingToken.safeTransfer(user, amount);
        emit Unstaked(user, amount);
    }
}

