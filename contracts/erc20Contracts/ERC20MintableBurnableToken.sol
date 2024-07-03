// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC20BurnableToken.sol";

contract ERC20MintableBurnableToken is ERC20BurnableToken {

    constructor(string memory _name, string memory _ticker, uint256 _initialSupply)
    ERC20BurnableToken(_name, _ticker, _initialSupply) {
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}
