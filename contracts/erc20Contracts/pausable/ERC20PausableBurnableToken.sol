// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";

contract ERC20PausableBurnableToken is ERC20, Pausable, ERC20Burnable, Ownable {

    mapping(address => bool) private _whitelistedContracts;

    constructor(string memory _name, string memory _ticker, uint256 _initialSupply)
    ERC20(_name, _ticker) Ownable(tx.origin){
        _transferOwnership(tx.origin);
        _mint(tx.origin, _initialSupply);
    }

    modifier whenNotPausedOrWhitelisted() {
        require(!paused() || msg.sender == owner() || _whitelistedContracts[msg.sender], "Pausable: paused and not whitelisted");
        _;
    }

    function addWhitelistedContract(address contractAddress) public onlyOwner {
        _whitelistedContracts[contractAddress] = !_whitelistedContracts[contractAddress];
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    // Override _update() to apply the custom logic (similar to _beforeTokenTransfer in v4)
    function _update(address from, address to, uint256 amount) internal virtual override(ERC20) whenNotPausedOrWhitelisted {
        super._update(from, to, amount);
    }
}
