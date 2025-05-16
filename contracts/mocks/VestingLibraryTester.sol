// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../VestingLibrary.sol";

contract VestingLibraryTester {
    function generateUUID(uint256 _id) external view returns (bytes32) {
        return VestingLibrary.generateUUID(_id);
    }

    function computeReleasableAmount(
        uint start,
        uint duration,
        uint period,
        uint lockUpPeriod,
        uint tgeAmount,
        uint invested,
        uint released
    ) external view returns (uint256) {
        return VestingLibrary.computeReleasableAmount(
            start,
            duration,
            period,
            lockUpPeriod,
            tgeAmount,
            invested,
            released
        );
    }
}
