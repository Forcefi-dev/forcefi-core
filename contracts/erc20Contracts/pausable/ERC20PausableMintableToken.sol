// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "./ERC20PausableToken.sol";

contract ERC20PausableMintableToken is ERC20PausableToken {

    constructor(string memory _name, string memory _ticker, uint256 _initialSupply)
    ERC20PausableToken(_name, _ticker, _initialSupply) {
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}
