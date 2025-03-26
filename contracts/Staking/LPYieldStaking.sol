// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
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

/// @title LPYieldStaking
/// @notice A staking contract that allows users to stake Uniswap V3 LP NFTs in exchange for yield rewards.
/// @dev Users stake NFTs representing liquidity positions and earn proportional rewards based on liquidity size.
contract LPYieldStaking is YieldStaking, IERC721Receiver {
    using SafeERC20 for ERC20;

    // State variables
    IUniswapV3PositionManager public immutable positionManager;

    ERC20 public immutable lpStakingToken1; // First token in the LP pair
    ERC20 public immutable lpStakingToken2; // Second token in the LP pair

    mapping(uint256 => uint256) public tokenLockupTimestamp; // Timestamp when an NFT was locked
    uint256 public immutable lockupPeriod; // Minimum lockup period for staked NFTs

    mapping(uint256 => address) public nftOwner; // Mapping of NFT token ID to owner
    mapping(address => uint256[]) public lockedNfts; // Mapping of user address to their staked NFTs

    /// @notice Initializes the LP yield staking contract.
    /// @param rewardsToken_ The token distributed as rewards.
    /// @param rewardsStart_ The start time of the rewards program.
    /// @param rewardsEnd_ The end time of the rewards program.
    /// @param totalRewards_ The total rewards available for distribution.
    /// @param lpStakingToken1_ The first token in the LP pair.
    /// @param lpStakingToken2_ The second token in the LP pair.
    /// @param _positionManager The Uniswap V3 position manager contract.
    /// @param _lockupPeriod The minimum period an NFT must be locked before unstaking.
    constructor(
        ERC20 rewardsToken_,
        uint256 rewardsStart_,
        uint256 rewardsEnd_,
        uint256 totalRewards_,
        ERC20 lpStakingToken1_,
        ERC20 lpStakingToken2_,
        IUniswapV3PositionManager _positionManager,
        uint256 _lockupPeriod
    ) YieldStaking(rewardsToken_, rewardsStart_, rewardsEnd_, totalRewards_) {
        lpStakingToken1 = lpStakingToken1_;
        lpStakingToken2 = lpStakingToken2_;
        positionManager = _positionManager;
        lockupPeriod = _lockupPeriod;
    }

    /// @notice Stake an LP NFT position.
    /// @param user The address of the user staking the NFT.
    /// @param tokenId The ID of the Uniswap V3 LP NFT being staked.
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
        tokenLockupTimestamp[tokenId] = block.timestamp;

        positionManager.safeTransferFrom(user, address(this), tokenId);

        emit Staked(user, tokenId);
    }

    /// @notice Unstake an LP NFT position.
    /// @param user The address of the user unstaking the NFT.
    /// @param tokenId The ID of the Uniswap V3 LP NFT being unstaked.
    function _unstake(address user, uint256 tokenId) internal virtual override {
        require(user == nftOwner[tokenId], "Only initial owner of NFT token can unstake");
        require(tokenLockupTimestamp[tokenId] + lockupPeriod <= block.timestamp, "Token lockup period hasn't passed");

        (, , , , , , , uint128 liquidity, , , ,) = positionManager.positions(tokenId);
        _updateUserRewards(user);
        totalStaked -= liquidity;
        userStake[user] -= liquidity;
        removeLockedNft(user, tokenId);

        positionManager.safeTransferFrom(address(this), user, tokenId);

        emit Unstaked(user, liquidity);
    }

    /// @notice Removes an NFT from a user's locked NFT list.
    /// @param user The address of the user.
    /// @param tokenId The ID of the NFT to remove.
    function removeLockedNft(address user, uint256 tokenId) internal {
        uint256[] storage userNfts = lockedNfts[user];
        for (uint256 i = 0; i < userNfts.length; i++) {
            if (userNfts[i] == tokenId) {
                userNfts[i] = userNfts[userNfts.length - 1]; // Replace with last element
                userNfts.pop(); // Remove last element
                break;
            }
        }
    }

    /// @notice Returns all locked NFTs for a given user.
    /// @param user The address of the user.
    /// @return An array of NFT token IDs owned by the user.
    function getLockedNfts(address user) external view returns (uint256[] memory) {
        return lockedNfts[user];
    }

    /// @notice Implements IERC721Receiver to allow the contract to receive ERC721 tokens.
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
