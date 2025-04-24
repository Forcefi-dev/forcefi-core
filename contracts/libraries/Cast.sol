// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

library Cast {
    function u128(uint256 x) internal pure returns (uint128 y) {
        require(x <= 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, "Cast overflow");
        y = uint128(x);
    }
}
