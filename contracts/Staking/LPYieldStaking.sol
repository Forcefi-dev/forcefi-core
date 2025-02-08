// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./YieldStaking.sol";

interface IUniswapV3PositionManager {
    function positions(uint256 tokenId) external view returns (
        uint96 nonce,
        address operator,
        address token0,
        address token1,
        uint24 fee,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity,
        uint256 feeGrowthInside0LastX128,
        uint256 feeGrowthInside1LastX128,
        uint128 tokensOwed0,
        uint128 tokensOwed1
    );
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
}

/// @title NftYieldStaking
/// @notice A permissionless staking contract for a single rewards program.
/// @dev Rewards are distributed linearly over a fixed period of time, with a fixed total rewards pool.
/// The rewards distribution is proportional to the amount staked by each user. Rewards tokens must
/// be locked in the contract before the staking period begins.
contract LPYieldStaking is YieldStaking{
    using SafeERC20 for ERC20;

    // State variables
    IUniswapV3PositionManager public immutable positionManager;

    ERC20 public immutable lpStakingToken1; // Token that users stake
    ERC20 public immutable lpStakingToken2; // Token that users stake

    mapping(uint256 => address) public nftOwner; // Mapping of nft token owner
    mapping(address => uint256 []) public lockedNfts; // Mapping of nft token owner

    constructor(
        ERC20 rewardsToken_,
        uint256 rewardsStart_,
        uint256 rewardsEnd_,
        uint256 totalRewards_,
        ERC20 lpStakingToken1_,
        ERC20 lpStakingToken2_,
        IUniswapV3PositionManager _positionManager
    ) YieldStaking(rewardsToken_, rewardsStart_, rewardsEnd_, totalRewards_) {
        lpStakingToken1 = lpStakingToken1_;
        lpStakingToken2 = lpStakingToken2_;

        positionManager = _positionManager;
    }

    function _stake(address user, uint256 tokenId) internal virtual override {
        (, , address token0, address token1, , , , uint128 liquidity, , , ,) = positionManager.positions(tokenId);
        require(liquidity > 0, "No liquidity in NFT");
        require(token0 == address(lpStakingToken1) || token1 == address(lpStakingToken1), "Invalid lpStakingToken1 token");
        require(token0 == address(lpStakingToken2) || token1 == address(lpStakingToken2), "Invalid lpStakingToken2 token");

        _updateUserRewards(user);
        totalStaked += liquidity;
        userStake[user] += liquidity;
        nftOwner[tokenId] = user;
        lockedNfts[user].push(tokenId);

        positionManager.safeTransferFrom(user, address(this), tokenId);

        emit Staked(user, tokenId);
    }

    /// @notice Unstake tokens.
    function _unstake(address user, uint256 tokenId) internal virtual override
    {
        require (user == nftOwner[tokenId], "Only initial owner of NFT token can unstake");

        (, , , , , , , uint128 liquidity, , , ,) = positionManager.positions(tokenId);
        _updateUserRewards(user);
        totalStaked -= liquidity;
        userStake[user] -= liquidity;
        removeLockedNft(user, tokenId);

        positionManager.safeTransferFrom(address(this), user, tokenId);

        emit Unstaked(user, liquidity);
    }

    function removeLockedNft(address user, uint256 tokenId) internal {
        uint256[] storage userNfts = lockedNfts[user];
        for (uint256 i = 0; i < userNfts.length; i++) {
            if (userNfts[i] == tokenId) {
                userNfts[i] = userNfts[userNfts.length - 1]; // Move last element to current index
                userNfts.pop(); // Remove the last element
                break;
            }
        }
    }

}

