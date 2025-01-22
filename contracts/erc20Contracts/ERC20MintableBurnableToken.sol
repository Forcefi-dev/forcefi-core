// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./ERC20BurnableToken.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ERC20MintableBurnableToken is ERC20BurnableToken, Ownable {

    constructor(string memory _name, string memory _ticker, uint256 _initialSupply, address _ownerAddress)
        ERC20BurnableToken(_name, _ticker, _initialSupply, _ownerAddress) Ownable(_ownerAddress){
        _transferOwnership(_ownerAddress);
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}
