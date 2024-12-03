// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./BaseStaking.sol";

contract ForcefiChildChainStaking is BaseStaking {
    /// @notice Constructor initializes the ForcefiChildChainStaking contract
    /// @param _forcefiFundraisingAddress The address where fundraising fees are sent
    constructor(address _forcefiFundraisingAddress, address _endpoint, address _delegate)
    BaseStaking(_forcefiFundraisingAddress, _endpoint, _delegate) {}

    /// @notice Handles incoming messages from LayerZero and processes staking or unstaking
    /// @param payload The payload containing the staking or unstaking details
    function _lzReceive(
        Origin calldata /*_origin*/,
        bytes32 /*_guid*/,
        bytes calldata payload,
        address /*_executor*/,
        bytes calldata /*_extraData*/
    ) internal override {
        (address _staker, uint _stakeAmount, uint _stakeId) = abi.decode(payload, (address, uint, uint));
        if (_stakeAmount > 0) {
            _setStaker(_stakeAmount, _staker, _stakeId);
        } else {
            unstake(_stakeId);
            hasStaked[_staker] = false;
            isInvestor[_staker] = false;
        }
    }

    /// @notice Sets a staker with the given stake amount and address
    /// @param _stakeAmount The amount of tokens staked
    /// @param _stakerAddress The address of the user who staked
    function _setStaker(uint _stakeAmount, address _stakerAddress, uint _stakeId) private {
        hasStaked[_stakerAddress] = true;
        if (_stakeAmount >= investorTreshholdAmount) {
            isInvestor[_stakerAddress] = true;
            activeStake[_stakeId] = ActiveStake(_stakeId, _stakerAddress, investorTreshholdAmount, block.timestamp, 0);
            investors.push(_stakeId);
        }
        emit Staked(msg.sender, _stakeAmount, _stakeId);
    }

    /// @notice Unstakes a given stake by ID and updates related data
    /// @param _stakeId The ID of the stake to be unstaked
    function unstake(uint _stakeId) private {
        activeStake[_stakeId].stakeAmount = 0;
        removeInvestor(_stakeId);
    }
}
