// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title ERC20PausableToken
 * @dev ERC20 Token that can be paused and has owner control.
 * Includes pausability and whitelist functionality for contracts.
 */
contract ERC20PausableToken is ERC20, Pausable, Ownable {
    // Mapping to keep track of whitelisted contracts
    mapping(address => bool) private _whitelistedContracts;

    /**
     * @dev Constructor that gives msg.sender all initial tokens and sets the name and symbol.
     * @param _name Name of the token.
     * @param _ticker Symbol of the token.
     * @param _initialSupply Initial token supply.
     */
    constructor(string memory _name, string memory _ticker, uint256 _initialSupply)
    ERC20(_name, _ticker) Ownable(tx.origin)
    {
        // Transfer ownership to the origin of the transaction
        _transferOwnership(tx.origin);
        // Mint initial supply to the owner
        _mint(tx.origin, _initialSupply);
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused,
     * or the caller is whitelisted.
     */
    modifier whenNotPausedOrWhitelisted() {
        require(!paused() || msg.sender == owner() || _whitelistedContracts[msg.sender],
            "Pausable: paused and not whitelisted");
        _;
    }

    /**
     * @dev Add or remove an address from whitelist.
     * @param contractAddress Address to be added or removed from the whitelist.
     */
    function addWhitelistedContract(address contractAddress) public onlyOwner {
        _whitelistedContracts[contractAddress] = !_whitelistedContracts[contractAddress];
    }

    /**
     * @dev Pause token transfers.
     */
    function pause() public onlyOwner {
        _pause();
    }

    /**
     * @dev Unpause token transfers.
     */
    function unpause() public onlyOwner {
        _unpause();
    }

    // Override _update() to apply the custom logic (similar to _beforeTokenTransfer in v4)
    function _update(address from, address to, uint256 amount) internal virtual override whenNotPausedOrWhitelisted {
        super._update(from, to, amount);
    }
}
