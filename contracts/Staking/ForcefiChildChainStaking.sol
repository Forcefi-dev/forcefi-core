// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./BaseStaking.sol";

contract ForcefiChildChainStaking is BaseStaking {
    constructor(address _forcefiFundraisingAddress, address _lzContractAddress)
    BaseStaking(_forcefiFundraisingAddress, _lzContractAddress) {}

    function _nonblockingLzReceive(uint16, bytes memory, uint64, bytes memory _payload) internal override {
        (address _staker, uint _stakeAmount, uint _stakeId) = abi.decode(_payload, (address, uint, uint));
        if(_stakeAmount > 0){
            _setStaker(_stakeAmount, _staker);
        } else unstake(_stakeId);
    }

    function _setStaker(uint _stakeAmount, address _stakerAddress) private {
        uint stakeId = _stakeIdCounter;
        _stakeIdCounter += 1;
        activeStake[stakeId] = ActiveStake(stakeId, _stakerAddress, _stakeAmount, block.timestamp, 0);
        userStakes[_stakerAddress].push(stakeId);

        if(_stakeAmount >= investorTreshholdAmount) {
            investors.push(stakeId);
        }
        emit Staked(msg.sender, _stakeAmount, stakeId);
    }

    function unstake(uint _stakeId) private {
        activeStake[_stakeId].stakeAmount = 0;
        removeStakeFromUser(msg.sender, _stakeId);
        removeInvestor(_stakeId);
    }
}
