// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

contract MockCuratorContract {
    uint private totalPercentage;
    mapping(address => mapping(bytes32 => uint)) private receivedFees;

    function setTotalPercentage(uint _percentage) external {
        totalPercentage = _percentage;
    }

    function getCurrentTotalPercentage(bytes32) external view returns (uint) {
        return totalPercentage;
    }

    function receiveCuratorFees(address _token, uint _amount, bytes32 _campaignId) external {
        receivedFees[_token][_campaignId] = _amount;
    }

    function getReceivedFee(address _token, bytes32 _campaignId) external view returns (uint) {
        return receivedFees[_token][_campaignId];
    }
}
