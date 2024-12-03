// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract InvestmentToken is ERC20 {

    uint constant MINTING_AMOUNT = 1000000000000000000000;

    constructor(string memory _name, string memory _ticker) ERC20(_name, _ticker) {}

    function mint() public {
        _mint(msg.sender, MINTING_AMOUNT);
    }

}
