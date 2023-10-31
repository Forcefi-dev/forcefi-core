// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import "./DFOOptionBase.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract DFORegistrationOption is DFOOptionBase {

    using Counters for Counters.Counter;
    using SafeMath for uint256;

    Counters.Counter public _tokenIdCounter;

    constructor(uint _executionPeriodTimestamp) DFOOptionBase(_executionPeriodTimestamp) {
    }

    function safeMint(address to, uint _fundraisedAmount) public override {
        require(whitelistedMinter[msg.sender], "Not whitelisted address to mint");

        uint strikePrice = IDFOTokenPriceFeed(priceFeedContractAddress).estimateAmountOut(
            tokenAddress,
            1,
            0
        );

        // Generate randomized execution block
        uint randomizedBlockCount = uint(blockhash(block.timestamp - 1)) % executionPeriodTimestamp;
        uint executionTimestamp = block.timestamp + executionPeriodTimestamp + randomizedBlockCount;
        uint executionTimestampEnd = executionTimestamp + 86400;
        uint optionPeriod = (block.timestamp - contractInitTimestamp) / monthlyTimestamp;

        for(uint i = 0; i < 5; i++){
            uint id = _tokenIdCounter.current();

            Option memory option = Option(to, executionTimestamp, executionTimestampEnd, id, false, optionPeriod, strikePrice, 0, false, 0);

            _tokenIdCounter.increment();

            myOptions[to].push(id);
            options[id] = option;
            optionsByPeriod[optionPeriod].push(id);
        }
    }

    function getPeriod(uint _id) public view returns(uint){
        Option storage op = options[_id];
        return optionsByPeriod[op.optionPeriod].length;
    }

    function getOptionTokenAmount(uint _id) internal view override returns(uint){
        // Get Total available tokens = 5,000,000 Tokens / month + unused tokens from previous periods
        Option storage _option = options[_id];
        uint dfosFounded = optionsByPeriod[_option.optionPeriod].length;
        uint currentBalance = IDFOToken(tokenAddress).balanceOf(address(this));
        uint currentBalanceInEther = currentBalance.div(1e18);
        if(5000000 > currentBalanceInEther){
            uint tokensPerProject = 5000000 / dfosFounded;
            if(tokensPerProject > 100000){
                tokensPerProject = 100000;
            }
            return tokensPerProject;
        } else {
            uint tokensPerProject = currentBalanceInEther / dfosFounded;
            if(tokensPerProject > 100000){
                tokensPerProject = 100000;
            }
            return tokensPerProject;
        }
    }
}
