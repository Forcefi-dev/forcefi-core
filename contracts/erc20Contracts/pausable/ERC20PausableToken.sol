// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract ERC20PausableToken is ERC20, Pausable, Ownable {

    mapping(address => bool) private _whitelistedContracts;

    constructor(string memory _name, string memory _ticker, uint256 _initialSupply)
    ERC20(_name, _ticker) {
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

    function _beforeTokenTransfer(address from, address to, uint amount) internal whenNotPausedOrWhitelisted override {
        super._beforeTokenTransfer(from, to, amount);
    }

}
