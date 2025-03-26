// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MockUniswapV3PositionManager {
    struct Position {
        uint96 nonce;
        address operator;
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        uint128 tokensOwed0;
        uint128 tokensOwed1;
    }

    mapping(uint256 => Position) public positionsData;
    mapping(uint256 => address) public tokenOwner; // Track ownership of tokenIds


    /// @notice Sets mock position data for a given tokenId
    function setPosition(uint256 tokenId, address _token0, address _token1, uint128 _liquidity) external {
        positionsData[tokenId] = Position(
            1,
            msg.sender,
            _token0,
            _token1,
            0,
            0,
            0,
            _liquidity,
            0,
            0,
            0,
            0
        );

        tokenOwner[tokenId] = msg.sender;
    }

    /// @notice Returns the stored position data
    function positions(uint256 tokenId) external view returns (Position memory) {
        return positionsData[tokenId];
    }

    /// @notice Transfers ownership of a tokenId from one address to another
    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        require(tokenOwner[tokenId] == from, "Caller is not owner");
        require(to != address(0), "Invalid recipient");

        tokenOwner[tokenId] = to; // Change ownership
    }
}
