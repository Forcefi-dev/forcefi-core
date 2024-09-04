// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @title VestingLibrary
 * @dev A library that provides functionality for calculating releasable vested amounts and generating unique identifiers (UUIDs).
 */
library VestingLibrary {
    using SafeMath for uint256;

    /**
     * @dev Computes the amount of tokens that can be released based on vesting parameters.
     *
     * @param start The start time of the vesting schedule (in seconds since Unix epoch).
     * @param duration The total duration of the vesting schedule (in seconds).
     * @param period The length of each vesting period (in seconds).
     * @param lockUpPeriod The initial lock-up period during which no tokens are released (in seconds).
     * @param tgeAmount The percentage of tokens to be released at the time of the Token Generation Event (TGE), represented as a whole number (e.g., 20 for 20%).
     * @param invested The total number of tokens vested to the beneficiary.
     * @param released The number of tokens that have already been released to the beneficiary.
     *
     * @return uint256 The number of tokens that can be released at the current time.
     */
    function computeReleasableAmount(
        uint start,
        uint duration,
        uint period,
        uint lockUpPeriod,
        uint tgeAmount,
        uint invested,
        uint released
    ) internal view returns (uint256) {
        uint256 currentTime = block.timestamp;

        // If the current time is past the total vesting duration plus the lock-up period, all remaining tokens are releasable.
        if (currentTime >= start.add(duration).add(lockUpPeriod)) {
            return invested.sub(released);
        } else {
            // Calculate the amount releasable at TGE
            uint256 tgeCalculatedAmount = invested.mul(tgeAmount).div(100);

            // If still within the lock-up period, only the TGE amount can be released.
            if (currentTime <= start.add(lockUpPeriod)) {
                return tgeCalculatedAmount.sub(released);
            }

            // Calculate time passed since the start of the vesting period, excluding the lock-up period.
            uint256 timeFromStart = currentTime.sub(start).sub(lockUpPeriod);

            // Calculate the number of vesting periods that have passed.
            uint256 vestedPeriods = timeFromStart.div(period);

            // Calculate the total number of periods in the entire vesting duration.
            uint256 totalPeriodsCount = duration.div(period);

            // Calculate the total vested amount proportional to the number of periods that have passed.
            uint256 vestedAmount = (invested.sub(tgeCalculatedAmount)).mul(vestedPeriods).div(totalPeriodsCount);

            // The releasable amount is the vested amount plus the TGE amount, minus the amount already released.
            return vestedAmount.add(tgeCalculatedAmount).sub(released);
        }
    }

    /**
     * @dev Generates a unique identifier (UUID) based on the current timestamp, sender address, and a given ID.
     *
     * @param _id An identifier to include in the UUID generation (e.g., a sequential ID or a unique contract identifier).
     *
     * @return bytes32 A unique identifier (UUID) based on the input parameters and current blockchain state.
     */
    function generateUUID(uint _id) internal view returns (bytes32) {
        return keccak256(abi.encodePacked(block.timestamp, msg.sender, _id));
    }
}
