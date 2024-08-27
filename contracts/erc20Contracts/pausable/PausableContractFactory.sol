// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./../ForcefiBaseContract.sol";
import "./ERC20PausableMintableBurnableToken.sol";
import "./ERC20PausableBurnableToken.sol";
import "./ERC20PausableMintableToken.sol";
import "./ERC20PausableToken.sol";

/**
 * @title PausableContractFactory
 * @dev This contract acts as a factory to create various types of pausable ERC20 tokens.
 * The factory can deploy pausable tokens with optional minting and burning capabilities.
 * Inherits from ForcefiBaseContract.
 */
contract PausableContractFactory is ForcefiBaseContract {

    /**
     * @dev Enum representing different types of pausable token contracts that can be created.
     * - Pausable: A pausable ERC20 token.
     * - PausableBurnable: A pausable ERC20 token with burning capabilities.
     * - PausableMintableBurnable: A pausable ERC20 token with both minting and burning capabilities.
     * - PausableMintable: A pausable ERC20 token with minting capabilities.
     */
    enum ContractType { Pausable, PausableBurnable, PausableMintableBurnable, PausableMintable }

    /**
     * @dev Emitted when a new token contract is created.
     * @param contractAddress Address of the newly deployed token contract.
     * @param deployer Address of the account that deployed the token contract.
     * @param projectName Name of the project associated with the token contract.
     */
    event ContractCreated(address indexed contractAddress, address indexed deployer, string projectName);

    /**
     * @dev Creates a new pausable token contract based on the specified type.
     * The function can deploy one of four types of pausable ERC20 tokens:
     * Pausable, PausableBurnable, PausableMintable, or PausableMintableBurnable.
     *
     * @param _type The type of token contract to create (from the ContractType enum).
     * @param _name The name of the token.
     * @param _ticker The ticker symbol of the token.
     * @param _projectName The name of the project associated with the token.
     * @param _initialSupply The initial supply of the token.
     *
     * @return The address of the newly created token contract.
     *
     * Requirements:
     * - The msg.sender must have the necessary creation tokens or pay the required fee.
     */
    function createContract(
        ContractType _type,
        string memory _name,
        string memory _ticker,
        string memory _projectName,
        uint256 _initialSupply
    ) external payable returns (address) {
        // Ensure the deployer has the required creation token or pays the appropriate fee
        bool hasCreationToken = IForcefiPackage(forcefiPackageAddress).hasCreationToken(msg.sender, _projectName);
        require(msg.value == feeAmount || hasCreationToken, "Invalid fee value or no creation token available");

        address newContract;

        // Deploy the appropriate contract type based on the provided enum value
        if (_type == ContractType.Pausable) {
            newContract = address(new ERC20PausableToken(_name, _ticker, _initialSupply));
        } else if (_type == ContractType.PausableMintable) {
            newContract = address(new ERC20PausableMintableToken(_name, _ticker, _initialSupply));
        } else if (_type == ContractType.PausableBurnable) {
            newContract = address(new ERC20PausableBurnableToken(_name, _ticker, _initialSupply));
        } else if (_type == ContractType.PausableMintableBurnable) {
            newContract = address(new ERC20PausableMintableBurnableToken(_name, _ticker, _initialSupply));
        } else {
            revert("Invalid contract type");
        }

        emit ContractCreated(newContract, msg.sender, _projectName);

        return newContract;
    }
}
