# Native Currency (ETH) Investment Guide

This guide explains how to use the new native currency (ETH) investment functionality in the Fundraising contract.

## Overview

The Fundraising contract has been enhanced to accept native currency (ETH) investments alongside ERC20 tokens. This allows investors to participate in fundraising campaigns using ETH directly.

## Key Features

1. **ETH Investment**: Investors can use ETH to participate in fundraising campaigns
2. **Chainlink Price Feeds**: ETH prices are fetched using Chainlink oracles for accurate conversion
3. **Fee Distribution**: ETH fees are properly distributed to platform, referral, and other stakeholders
4. **Reclaim Functionality**: Investors can reclaim ETH from failed campaigns

## Setup Process

### 1. Whitelist Native Currency Globally

First, the contract owner must whitelist native currency for investment globally:

```solidity
// Deploy or get reference to ETH/USD Chainlink price feed
address ethUsdPriceFeed = "0x..."; // ETH/USD price feed address

// Whitelist native currency for investment
fundraisingContract.whitelistNativeCurrencyForInvestment(ethUsdPriceFeed);
```

### 2. Add Native Currency to Campaign Whitelist

Campaign owners can add native currency to their specific campaign:

```solidity
// Add native currency to campaign whitelist
fundraisingContract.addNativeCurrencyToWhitelist(campaignId);
```

## Investment Process

### For Investors

Investors can now use ETH to invest in campaigns that have whitelisted native currency:

```solidity
// Investment parameters
uint256 projectTokenAmount = 1000; // Amount of project tokens to receive
bytes32 campaignId = "0x..."; // Campaign ID

// Calculate required ETH amount (or let the contract handle it)
// The contract will calculate the exact ETH needed based on:
// - Current ETH price from Chainlink
// - Campaign exchange rate
// - Project token amount desired

// Invest with ETH (send more than required, excess will be refunded)
fundraisingContract.investWithNativeCurrency{value: 1 ether}(
    projectTokenAmount,
    campaignId
);
```

### Key Points for ETH Investment

1. **Automatic Calculation**: The contract automatically calculates the required ETH amount based on Chainlink price feeds
2. **Excess Refund**: If you send more ETH than required, the excess is automatically refunded
3. **Price Protection**: The contract uses the latest ETH price from Chainlink oracles

## Reading Balances

### Get Native Currency Balance

```solidity
// Get your ETH contribution to a specific campaign
uint256 ethBalance = fundraisingContract.getNativeCurrencyBalance(campaignId);

// Get total ETH raised for a campaign
uint256 totalEthRaised = fundraisingContract.getTotalNativeCurrencyRaised(campaignId);
```

## Campaign Management

### For Campaign Owners

#### Closing Successful Campaigns

When closing a successful campaign, ETH is distributed as follows:

1. **Referral Fees**: Sent to referral address (if configured)
2. **Platform Fees**: Sent to platform fee address
3. **Remaining Amount**: Sent to campaign owner

#### Failed Campaigns

Campaign owners can unlock funds from failed campaigns, returning unsold project tokens.

### For Investors

#### Claiming Tokens

After a successful campaign closes, investors can claim their project tokens according to the vesting schedule:

```solidity
fundraisingContract.claimTokens(campaignId);
```

#### Reclaiming ETH

If a campaign fails to reach its minimum threshold, investors can reclaim their ETH:

```solidity
fundraisingContract.reclaimTokens(campaignId);
```

## Contract Constants

- `NATIVE_CURRENCY`: `address(0)` - Represents native currency (ETH) in the system
- ETH has 18 decimals, which is handled automatically by the contract

## Events

The contract emits the same events for ETH investments as for ERC20 investments:

- `Invested`: When an ETH investment is made
- `TokensReclaimed`: When ETH is reclaimed from a failed campaign
- `ReferralFeeSent`: When referral fees are sent in ETH

## Security Considerations

1. **Price Feed Reliability**: The contract relies on Chainlink price feeds for ETH pricing
2. **Reentrancy Protection**: The contract should be audited for reentrancy issues when handling ETH transfers
3. **Gas Optimization**: ETH transfers consume gas, ensure sufficient gas limits for transactions

## Example Usage

```javascript
// JavaScript example using ethers.js

// 1. Whitelist ETH for investment (contract owner)
await fundraisingContract.whitelistNativeCurrencyForInvestment(ethUsdPriceFeedAddress);

// 2. Create campaign and add ETH to whitelist (campaign owner)
const campaignId = await createCampaign(/* campaign parameters */);
await fundraisingContract.addNativeCurrencyToWhitelist(campaignId);

// 3. Invest with ETH (investor)
const projectTokenAmount = ethers.parseUnits("1000", 18);
await fundraisingContract.investWithNativeCurrency(
    projectTokenAmount,
    campaignId,
    { value: ethers.parseEther("0.5") } // Send 0.5 ETH, excess will be refunded
);

// 4. Check balance
const ethBalance = await fundraisingContract.getNativeCurrencyBalance(campaignId);
console.log("ETH invested:", ethers.formatEther(ethBalance));

// 5. Reclaim ETH if campaign fails
await fundraisingContract.reclaimTokens(campaignId);
```

## Testing

Run the ETH investment tests:

```bash
npx hardhat test --grep "Native Currency"
```

This will run all tests related to the native currency investment functionality.
