// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./ERC20PausableToken.sol";

contract ERC20PausableMintableToken is ERC20PausableToken {

    constructor(string memory _name, string memory _ticker, uint256 _initialSupply, address _ownerAddress)
    ERC20PausableToken(_name, _ticker, _initialSupply, _ownerAddress) {
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}
