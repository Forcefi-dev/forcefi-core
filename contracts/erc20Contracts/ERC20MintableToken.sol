// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "./ERC20Token.sol";

contract ERC20MintableToken is ERC20Token {

    constructor(string memory _name, string memory _ticker, uint256 _initialSupply)
    ERC20Token(_name, _ticker, _initialSupply) {
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}
