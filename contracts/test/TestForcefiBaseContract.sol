// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../ForcefiBaseContract.sol";

/**
 * @title TestForcefiBaseContract
 * @dev A test contract that extends ForcefiBaseContract and allows simulation of fee collection
 * This contract is only for testing purposes
 */
contract TestForcefiBaseContract is ForcefiBaseContract {
    
    /**
     * @dev Allow the contract to receive ETH and simulate fee collection
     */
    receive() external payable {
        collectedFees += msg.value;
    }
    
    /**
     * @dev Fallback function to receive ETH
     */
    fallback() external payable {
        collectedFees += msg.value;
    }
    
    /**
     * @dev Function to simulate fee collection for testing
     * @param amount The amount of fees to collect
     */
    function simulateFeeCollection(uint256 amount) external payable {
        require(msg.value >= amount, "Insufficient ETH sent");
        collectedFees += amount;
        
        // Return excess ETH if any
        if (msg.value > amount) {
            payable(msg.sender).transfer(msg.value - amount);
        }
    }
    
    /**
     * @dev Function to manually set collected fees for testing
     * @param amount The amount to set as collected fees
     */
    function setCollectedFeesForTesting(uint256 amount) external onlyOwner {
        collectedFees = amount;
    }
}
