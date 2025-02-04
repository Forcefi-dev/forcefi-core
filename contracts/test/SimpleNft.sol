// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract SimpleNFT is ERC721 {
    uint256 public stakeIdCounter; // Token ID tracker

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {
        stakeIdCounter = 1; // Start token IDs from 1
    }

    function mintNFT() external {
        uint256 tokenId = stakeIdCounter;
        stakeIdCounter++;
        _safeMint(msg.sender, tokenId);
    }
}
