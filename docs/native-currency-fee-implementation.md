# Native Currency Fee Implementation

This document explains how the native currency (ETH) fee distribution has been implemented for the staking and curator contracts, allowing them to handle ETH fees in the same way as ERC20 tokens.

## Overview

The implementation allows the `closeCampaign` function in the Fundraising contract to distribute ETH fees to staking and curator contracts using payable functions, similar to how ERC20 token fees are distributed.

## Implementation Details

### 1. Updated Interfaces

The interfaces have been extended to include payable functions for native currency:

```solidity
interface IForcefiStaking {
    function hasAddressStaked(address) external view returns(bool);
    function receiveFees(address, uint) external;
    function receiveNativeCurrencyFees() external payable; // New function
}

interface IForcefiCuratorContract {
    function receiveCuratorFees(address, uint, bytes32) external;
    function receiveNativeCurrencyFees(bytes32) external payable; // New function
    function getCurrentTotalPercentage(bytes32) external view returns (uint);
}
```

### 2. Fundraising Contract Updates

The `closeCampaign` function now properly handles ETH fee distribution with try-catch blocks for graceful fallback:

```solidity
// Handle staking fee (3/10 of the remaining base fee) for native currency
if(forcefiStakingAddress != address(0)) {
    uint stakingFee = remainingBaseFee * 3 / 10;
    // Try to send ETH to staking contract
    try IForcefiStaking(forcefiStakingAddress).receiveNativeCurrencyFees{value: stakingFee}() {
        distributedFees += stakingFee;
    } catch {
        // If staking contract doesn't support ETH, the fee remains with campaign owner
        // This provides fallback behavior without reverting the transaction
    }
}

// Handle curator fee (1/2 of the remaining base fee) for native currency
if(curatorContractAddress != address(0)) {
    uint curatorFee = remainingBaseFee / 2;
    uint curatorPercentage = IForcefiCuratorContract(curatorContractAddress).getCurrentTotalPercentage(_fundraisingIdx);
    uint adjustedCuratorFee = curatorFee * curatorPercentage / 100;
    if (adjustedCuratorFee > 0) {
        // Try to send ETH to curator contract
        try IForcefiCuratorContract(curatorContractAddress).receiveNativeCurrencyFees{value: adjustedCuratorFee}(_fundraisingIdx) {
            distributedFees += adjustedCuratorFee;
        } catch {
            // If curator contract doesn't support ETH, the fee remains with campaign owner
            // This provides fallback behavior without reverting the transaction
        }
    }
}
```

**Key Features:**
- Uses try-catch blocks for graceful error handling
- If contracts don't support ETH fees, the transaction doesn't revert
- Fees that can't be distributed remain with the campaign owner
- Backward compatibility with existing contracts

### 3. CuratorContract Updates

#### New Function: `receiveNativeCurrencyFees`
```solidity
function receiveNativeCurrencyFees(bytes32 fundraisingIdx) external payable {
    require(msg.sender == fundraisingAddress, "Only fundraising contract can distribute fees");
    require(msg.value > 0, "Amount must be greater than 0");

    CuratorData[] memory curators = fundraisingCurators[fundraisingIdx];
    require(curators.length > 0, "No curators to distribute fees to");

    // Use address(0) to represent native currency
    address nativeCurrency = address(0);
    emit FeesReceived(fundraisingIdx, nativeCurrency, msg.value);

    for (uint i = 0; i < curators.length; i++) {
        uint256 curatorShare = (msg.value * curators[i].percentage) / MAX_TOTAL_PERCENTAGE;
        if (curatorShare > 0) {
            unclaimedFees[curators[i].curatorAddress][nativeCurrency] += curatorShare;
            emit FeesDistributed(fundraisingIdx, curators[i].curatorAddress, curatorShare);
        }
    }
}
```

#### Updated `claimCuratorFees` Function
```solidity
function claimCuratorFees(address erc20TokenAddress) external {
    uint256 amount = unclaimedFees[msg.sender][erc20TokenAddress];
    require(amount > 0, "No fees to claim");

    unclaimedFees[msg.sender][erc20TokenAddress] = 0;
    
    if (erc20TokenAddress == address(0)) {
        // Handle native currency (ETH)
        payable(msg.sender).transfer(amount);
    } else {
        // Handle ERC20 tokens
        require(
            IERC20(erc20TokenAddress).transfer(msg.sender, amount),
            "Fee transfer failed"
        );
    }
    
    emit FeesClaimed(msg.sender, erc20TokenAddress, amount);
}
```

### 4. BaseStaking Contract Updates

#### New Function: `receiveNativeCurrencyFees`
```solidity
function receiveNativeCurrencyFees() external payable {
    require(msg.sender == forcefiFundraisingAddress, "Not fundraising address");
    require(msg.value > 0, "No fees to distribute");
    
    address[] memory eligibleFeeReceivers = new address[](investors.length);
    uint256 count = 0;

    // Iterate over all investors and calculate their eligible stake for fee distribution
    for (uint256 i = 0; i < investors.length; i++) {
        // Check if the stake is eligible for receiving fees
        if (activeStake[investors[i]].stakeEventTimestamp + eligibleToReceiveFeeTime < block.timestamp) {
            eligibleFeeReceivers[count] = investors[i];
            count++;
        }
    }

    // Distribute fees based on calculated multipliers
    if (count > 0) {
        uint256 feeShare = msg.value / count;
        // Use address(0) to represent native currency
        address nativeCurrency = address(0);
        for (uint256 j = 0; j < count; j++) {
            investorTokenBalance[eligibleFeeReceivers[j]][nativeCurrency] += feeShare;
        }
    }
    // TODO: Send to treasury if no eligible receivers
    else {
        // For now, the contract holds the ETH if no eligible receivers
        // This should be modified to send to treasury in the future
    }
}
```

#### Updated `claimFees` Function
```solidity
function claimFees(address _feeTokenAddress) external nonReentrant{
    uint tokenBalance = investorTokenBalance[msg.sender][_feeTokenAddress];
    require(tokenBalance > 0, "No fees to claim");
    
    investorTokenBalance[msg.sender][_feeTokenAddress] = 0;
    
    if (_feeTokenAddress == address(0)) {
        // Handle native currency (ETH)
        payable(msg.sender).transfer(tokenBalance);
    } else {
        // Handle ERC20 tokens
        IERC20(_feeTokenAddress).transfer(msg.sender, tokenBalance);
    }
}
```

## Usage

### For Campaign Owners
When closing a campaign that accepted ETH investments, the fees will be automatically distributed:
- Referral fees: Sent directly to referral address
- Platform fees: Sent to platform fee address
- Staking fees: Sent to staking contract (if it supports ETH)
- Curator fees: Sent to curator contract (if it supports ETH)
- Remaining funds: Sent to campaign owner

### For Curators
Curators can claim ETH fees by calling:
```solidity
// Claim ETH fees
curatorContract.claimCuratorFees(address(0));

// Claim ERC20 token fees
curatorContract.claimCuratorFees(tokenAddress);
```

### For Stakers
Stakers can claim ETH fees by calling:
```solidity
// Claim ETH fees
stakingContract.claimFees(address(0));

// Claim ERC20 token fees
stakingContract.claimFees(tokenAddress);
```

## Convention

- **Native Currency Representation**: `address(0)` is used consistently to represent native currency (ETH)
- **Fee Storage**: Both contracts use the same mapping structure for ERC20 and ETH fees
- **Claiming**: The same claim functions handle both token types based on the address parameter

## Benefits

1. **Unified Interface**: Both ERC20 and ETH fees use similar patterns
2. **Backward Compatibility**: Existing functionality for ERC20 tokens remains unchanged
3. **Graceful Fallback**: If contracts don't support ETH, transactions don't fail
4. **Consistent User Experience**: Users interact with ETH fees the same way as token fees
5. **Upgrade Path**: Contracts can be upgraded to support ETH without breaking existing functionality

## Security Considerations

1. **Reentrancy Protection**: The staking contract uses `nonReentrant` modifier for claiming
2. **Access Control**: Only authorized contracts can distribute fees
3. **Amount Validation**: All functions validate that amounts are greater than zero
4. **Try-Catch Safety**: Fee distribution uses try-catch to prevent transaction failures

This implementation successfully allows the staking and curator contracts to handle ETH fees in the same manner as ERC20 tokens, providing a seamless experience for users while maintaining backward compatibility.
