// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

contract MockedV3Aggregator {
    uint8 public decimals;
    int256 public latestAnswer;

    constructor(uint8 _decimals, int256 _initialAnswer) {
        decimals = _decimals;
        latestAnswer = _initialAnswer;
    }

    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (
            0, // roundId
            latestAnswer,
            0, // startedAt
            block.timestamp, // updatedAt
            0 // answeredInRound
        );
    }

    function setLatestAnswer(int256 _answer) external {
        latestAnswer = _answer;
    }
}
