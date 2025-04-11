// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract SimpleNFT is ERC721 {
    uint256 public stakeIdCounter; // Token ID tracker

    // Track tokens owned by each address
    mapping(address => uint256[]) private _ownedTokens;

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {
        stakeIdCounter = 1; // Start token IDs from 1
    }

    function mintNFT() external {
        uint256 tokenId = stakeIdCounter;
        stakeIdCounter++;
        _safeMint(msg.sender, tokenId);
        _ownedTokens[msg.sender].push(tokenId);
    }

    // Return tokenId by address and index
    function owner(address _ownerAddress, uint256 _idx) external view returns (uint256) {
        require(_idx < _ownedTokens[_ownerAddress].length, "Index out of bounds");
        return _ownedTokens[_ownerAddress][_idx];
    }

    // Optional: get all token IDs of an owner
    function tokensOfOwner(address _ownerAddress) external view returns (uint256[] memory) {
        return _ownedTokens[_ownerAddress];
    }
}
