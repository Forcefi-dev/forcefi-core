// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

library VestingLibrary {
    using SafeMath for uint256;

    function computeReleasableAmount(uint start, uint duration, uint period, uint lockUpPeriod, uint tgeAmount, uint invested, uint released) internal view returns(uint256){
        uint256 currentTime = block.timestamp;
        if (currentTime >= start.add(duration).add(lockUpPeriod)) {
            return invested.sub(released);
        } else {
            uint256 tgeCalculatedAmount = invested * tgeAmount / 100;
            if(currentTime <= start.add(lockUpPeriod)){
                return tgeCalculatedAmount.sub(released);
            }
            uint256 timeFromStart = currentTime.sub(start).sub(lockUpPeriod);
            uint256 vestedPeriods = timeFromStart.div(period);
            uint256 totalPeriodsCount = duration.div(period);
            uint256 vestedAmount = (invested - tgeCalculatedAmount).mul(vestedPeriods).div(totalPeriodsCount);

            return vestedAmount.add(tgeCalculatedAmount).sub(released);
        }
    }

    function generateUUID(uint _id) internal view returns (bytes32) {
        return keccak256(abi.encodePacked(block.timestamp, msg.sender, _id));
    }
}
