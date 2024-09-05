// SPDX-License-Identifier: MIT
pragma solidity 0.8.20 ;

import "./ERC20PausableBurnableToken.sol";

contract ERC20PausableMintableBurnableToken is ERC20PausableBurnableToken {

    constructor(string memory _name, string memory _ticker, uint256 _initialSupply)
    ERC20PausableBurnableToken(_name, _ticker, _initialSupply) {
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}
