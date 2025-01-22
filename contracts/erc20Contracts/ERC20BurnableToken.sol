// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract ERC20BurnableToken is ERC20Burnable {

    constructor(string memory _name, string memory _ticker, uint256 _initialSupply, address _ownerAddress)
    ERC20(_name, _ticker) {
        _mint(_ownerAddress, _initialSupply);
    }
}
