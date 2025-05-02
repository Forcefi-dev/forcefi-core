// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockCuratorContract {
    mapping(bytes32 => uint256) public totalPercentage;
    mapping(address => mapping(bytes32 => uint)) private receivedFees;

    function getCurrentTotalPercentage(bytes32 _fundraisingId) external view returns (uint) {
        return totalPercentage[_fundraisingId] > 0 ? totalPercentage[_fundraisingId] : 0;
    }

    function receiveCuratorFees(address _token, uint _amount, bytes32 _fundraisingId) external {
        IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        receivedFees[_token][_fundraisingId] = _amount;
    }

    function setTotalPercentage(bytes32 _fundraisingId, uint256 _percentage) external {
        totalPercentage[_fundraisingId] = _percentage;
    }

    function getReceivedFee(address _token, bytes32 _campaignId) external view returns (uint) {
        return receivedFees[_token][_campaignId];
    }
}
