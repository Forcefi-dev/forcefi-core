// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title IForcefiPackage
 * @dev Interface for the Forcefi package contract.
 * This interface defines a function to check if an address has a creation token for a specific project.
 */
interface IForcefiPackage {
    /**
     * @dev Checks if the given address has a creation token for the specified project.
     * @param ownerAddress The address to check for the creation token.
     * @param projectName The name of the project associated with the creation token.
     * @return bool True if the address has a creation token for the project, false otherwise.
     */
    function hasCreationToken(address ownerAddress, string memory projectName) external view returns (bool);
}

/**
 * @title ForcefiBaseContract
 * @dev A base contract for the Forcefi ecosystem, providing basic functionality for managing fees and the Forcefi package address.
 * This contract is owned, allowing only the owner to modify certain parameters like the fee amount and Forcefi package address.
 */
contract ForcefiBaseContract is Ownable {

    // The fee amount required for certain actions in the contract
    uint public collectedFees;

    // The fee amount required for certain actions in the contract
    uint public feeAmount;

    // The address of the Forcefi package contract, which provides functionality related to creation tokens
    address public forcefiPackageAddress;

    /**
     * @notice Emitted when the fee amount is updated
     * @param oldFeeAmount The previous fee amount
     * @param newFeeAmount The new fee amount
     */
    event FeeAmountUpdated(uint256 oldFeeAmount, uint256 newFeeAmount);

    /**
     * @notice Emitted when the Forcefi package address is updated
     * @param oldAddress The previous package address
     * @param newAddress The new package address
     */
    event ForcefiPackageAddressUpdated(address indexed oldAddress, address indexed newAddress);

    /**
     * @notice Emitted when fees are withdrawn
     * @param receiver The address that received the fees
     * @param amount The amount of fees withdrawn
     */
    event FeesWithdrawn(address indexed receiver, uint256 amount);

    /**
     * @dev Constructor for the ForcefiBaseContract.
     * Initializes the contract without setting the fee amount or the Forcefi package address.
     */
    constructor() Ownable(msg.sender){
    }

    /**
     * @dev Sets the fee amount for actions in the contract.
     * This function can only be called by the owner of the contract.
     * @param _feeAmount The new fee amount to be set.
     */
    function setFeeAmount(uint _feeAmount) public onlyOwner {
        uint oldFeeAmount = feeAmount;
        feeAmount = _feeAmount;
        emit FeeAmountUpdated(oldFeeAmount, _feeAmount);
    }
    
    /**
     * @dev Sets the address of the Forcefi package contract.
     * This function can only be called by the owner of the contract.
     * @param _forcefiPackageAddress The address of the Forcefi package contract to be set.
     */
    function setForcefiPackageAddress(address _forcefiPackageAddress) public onlyOwner {
        require(_forcefiPackageAddress != address(0), "ForcefiPackage address cannot be zero");
        address oldAddress = forcefiPackageAddress;
        forcefiPackageAddress = _forcefiPackageAddress;
        emit ForcefiPackageAddressUpdated(oldAddress, _forcefiPackageAddress);
    }

    /**
     * @dev Withdraws all fees from the contract.
     * This function can only be called by the owner of the contract.
     * @param receiver The address of the address that will receive all the fees collected by the contract.
     */
    function withdrawCollectedFees(address payable receiver) public onlyOwner{
        require(receiver != address(0), "Receiver address cannot be zero");
        require(collectedFees > 0, "No fees to withdraw");
        uint256 amount = collectedFees;
        collectedFees = 0;
        receiver.transfer(amount);
        emit FeesWithdrawn(receiver, amount);
    }
}
