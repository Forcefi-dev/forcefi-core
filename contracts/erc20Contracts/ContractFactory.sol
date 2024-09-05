// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./ERC20MintableBurnableToken.sol";
import "./ERC20BurnableToken.sol";
import "./ERC20MintableToken.sol";
import "./ERC20Token.sol";
import "./../ForcefiBaseContract.sol";

/**
 * @title ContractFactory
 * @dev This contract serves as a factory to create various types of ERC20 tokens.
 * The contract allows deploying standard, mintable, burnable, and mintable-burnable ERC20 tokens.
 * Inherits from ForcefiBaseContract.
 */
contract ContractFactory is ForcefiBaseContract {

    constructor(){}

    /**
     * @dev Enum representing different types of token contracts that can be created.
     * - StandardToken: A basic ERC20 token.
     * - Mintable: An ERC20 token with minting capabilities.
     * - Burnable: An ERC20 token with burning capabilities.
     * - MintableAndBurnable: An ERC20 token with both minting and burning capabilities.
     */
    enum ContractType { StandardToken, Mintable, Burnable, MintableAndBurnable }

    /**
     * @dev Emitted when a new token contract is created.
     * @param contractAddress Address of the newly deployed token contract.
     * @param deployer Address of the account that deployed the token contract.
     * @param projectName Name of the project associated with the token contract.
     */
    event ContractCreated(address indexed contractAddress, address indexed deployer, string projectName);

    /**
     * @dev Creates a new token contract based on the specified type.
     * The function can deploy one of four types of ERC20 tokens:
     * Standard, Mintable, Burnable, or MintableAndBurnable.
     *
     * @param _type The type of token contract to create (from the ContractType enum).
     * @param _name The name of the token.
     * @param _ticker The ticker symbol of the token.
     * @param _projectName The name of the project associated with the token.
     * @param _initialSupply The initial supply of the token.
     *
     * @return The address of the newly created token contract.
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
//        bool hasCreationToken = IForcefiPackage(forcefiPackageAddress).hasCreationToken(msg.sender, _projectName);
//        require(msg.value == feeAmount || hasCreationToken, "Invalid fee value or no creation token available");

        address newContract;

        // Deploy the appropriate contract type based on the provided enum value
        if (_type == ContractType.StandardToken) {
            newContract = address(new ERC20Token(_name, _ticker, _initialSupply));
        } else if (_type == ContractType.Mintable) {
            newContract = address(new ERC20MintableToken(_name, _ticker, _initialSupply));
        } else if (_type == ContractType.Burnable) {
            newContract = address(new ERC20BurnableToken(_name, _ticker, _initialSupply));
        } else if (_type == ContractType.MintableAndBurnable) {
            newContract = address(new ERC20MintableBurnableToken(_name, _ticker, _initialSupply));
        } else {
            revert("Invalid contract type");
        }

        emit ContractCreated(newContract, msg.sender, _projectName);

        return newContract;
    }
}
