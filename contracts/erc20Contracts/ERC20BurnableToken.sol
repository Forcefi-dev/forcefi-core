// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ERC20BurnableToken is ERC20Burnable, Ownable {

    constructor(string memory _name, string memory _ticker, uint256 _initialSupply)
    ERC20(_name, _ticker) {
        _transferOwnership(tx.origin);
        _mint(tx.origin, _initialSupply);
    }
}
