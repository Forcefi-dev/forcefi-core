// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./BaseStaking.sol";

contract ForcefiChildChainStaking is BaseStaking {
    /// @notice Constructor initializes the ForcefiChildChainStaking contract
    /// @param _forcefiFundraisingAddress The address where fundraising fees are sent
    /// @param _lzContractAddress The LayerZero contract address used for cross-chain communication
    constructor(address _forcefiFundraisingAddress, address _lzContractAddress)
    BaseStaking(_forcefiFundraisingAddress, _lzContractAddress) {}

    /// @notice Handles incoming messages from LayerZero and processes staking or unstaking
    /// @param _srcChainId The source chain ID from which the message originated
    /// @param _srcAddress The source address from which the message was sent
    /// @param _nonce The unique nonce of the message
    /// @param _payload The payload containing the staking or unstaking details
    function _nonblockingLzReceive(uint16 _srcChainId, bytes memory _srcAddress, uint64 _nonce, bytes memory _payload) internal override {
        (address _staker, uint _stakeAmount, uint _stakeId) = abi.decode(_payload, (address, uint, uint));
        if (_stakeAmount > 0) {
            _setStaker(_stakeAmount, _staker);
        } else {
            unstake(_stakeId);
        }
    }

    /// @notice Sets a staker with the given stake amount and address
    /// @param _stakeAmount The amount of tokens staked
    /// @param _stakerAddress The address of the user who staked
    function _setStaker(uint _stakeAmount, address _stakerAddress) private {
        uint stakeId = _stakeIdCounter;
        _stakeIdCounter += 1;
        activeStake[stakeId] = ActiveStake(stakeId, _stakerAddress, _stakeAmount, block.timestamp, 0);
        userStakes[_stakerAddress].push(stakeId);

        if (_stakeAmount >= investorTreshholdAmount) {
            investors.push(stakeId);
        }
        emit Staked(msg.sender, _stakeAmount, stakeId);
    }

    /// @notice Unstakes a given stake by ID and updates related data
    /// @param _stakeId The ID of the stake to be unstaked
    function unstake(uint _stakeId) private {
        activeStake[_stakeId].stakeAmount = 0;
        removeStakeFromUser(msg.sender, _stakeId);
        removeInvestor(_stakeId);
    }
}
