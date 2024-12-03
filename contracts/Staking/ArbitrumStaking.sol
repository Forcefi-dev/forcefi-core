// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./BaseStaking.sol";

interface INFTContract {
    function isOwnerOf(address, uint) external view returns(bool);
}

contract ArbitrumStaking is BaseStaking {

    address public forcefiSilverNFTAddress;
    address public forcefiGoldNFTAddress;
    mapping(uint => bool) public nftBridged;

    /// @notice Constructor initializes the ForcefiChildChainStaking contract
    /// @param _forcefiSilverNFTAddress The address of Forcefi Silver NFT contract
    /// @param _forcefiGoldNFTAddress The address of Forcefi Gold NFT contract
    /// @param _forcefiFundraisingAddress The address where fundraising fees are sent
    constructor(address _forcefiSilverNFTAddress, address _forcefiGoldNFTAddress, address _forcefiFundraisingAddress, address _endpoint, address _delegate)
    BaseStaking(_forcefiFundraisingAddress, _endpoint, _delegate) {
        forcefiSilverNFTAddress = _forcefiSilverNFTAddress;
        forcefiGoldNFTAddress = _forcefiGoldNFTAddress;
    }

    // No logic to implement
    function _lzReceive(
        Origin calldata /*_origin*/,
        bytes32 /*_guid*/,
        bytes calldata payload,
        address /*_executor*/,
        bytes calldata /*_extraData*/
    ) internal override {
        // No logic to implement
    }

    /// @notice Sets a staker with the given stake amount and address
    /// @param _stakeAmount The amount of tokens staked
    /// @param _stakerAddress The address of the user who staked
    function _setStaker(uint _stakeAmount, address _stakerAddress, uint _stakeId) private {
        hasStaked[_stakerAddress] = true;
        if (_stakeAmount >= investorTreshholdAmount) {
            isInvestor[_stakerAddress] = true;
            activeStake[_stakeId] = ActiveStake(_stakeId, _stakerAddress, investorTreshholdAmount, block.timestamp, 0);
            investors.push(_stakeId);
        }
        emit Staked(msg.sender, _stakeAmount, _stakeId);
    }

    /// @notice Unstakes a given stake by ID and updates related data
    /// @param _stakeId The ID of the stake to be unstaked
    function unstake(uint _stakeId) private {
        activeStake[_stakeId].stakeAmount = 0;
        removeInvestor(_stakeId);
    }

    function bridgeStakingAccess(uint16 _destChainId, bytes calldata _options, uint _stakeId) public payable {

        // check if owner of NFT
        require(INFTContract(forcefiSilverNFTAddress).isOwnerOf(msg.sender, _stakeId), "Not eligable to bridge access");

        // check if ID wasn't used before
        require(!nftBridged[_stakeId], "NFT already bridged");

        // Set id as used in mapping
        nftBridged[_stakeId] = true;

        bytes memory payload = abi.encode(msg.sender);

        _lzSend(_destChainId, payload, _options, MessagingFee(msg.value, 0), payable(msg.sender));
    }
}
