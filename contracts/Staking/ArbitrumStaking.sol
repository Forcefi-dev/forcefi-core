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
    mapping(uint => bool) public goldNftBridged;

    /// @notice Constructor initializes the ForcefiChildChainStaking contract
    /// @param _forcefiSilverNFTAddress The address of Forcefi Silver NFT contract
    /// @param _forcefiGoldNFTAddress The address of Forcefi Gold NFT contract
    /// @param _forcefiFundraisingAddress The address where fundraising fees are sent
    constructor(address _forcefiSilverNFTAddress, address _forcefiGoldNFTAddress, address _forcefiFundraisingAddress, address _endpoint, address _delegate)
    BaseStaking(_forcefiFundraisingAddress, _endpoint, _delegate) {
        forcefiSilverNFTAddress = _forcefiSilverNFTAddress;
        forcefiGoldNFTAddress = _forcefiGoldNFTAddress;
    }

    function _lzReceive(
        Origin calldata /*_origin*/,
        bytes32 /*_guid*/,
        bytes calldata payload,
        address /*_executor*/,
        bytes calldata /*_extraData*/
    ) internal override {
        (address _staker, uint _stakeAmount, uint _stakeId, uint _silverNftId, uint _goldNftId) = abi.decode(payload, (address, uint, uint, uint, uint));
        if (_stakeAmount > 0) {
            _setStaker(_stakeAmount, _staker, _stakeId, _silverNftId, _goldNftId);
        } else {
            unstake(_staker);
            hasStaked[_staker] = false;
            isInvestor[_staker] = false;
        }
    }

    /// @notice Sets a staker with the given stake amount and address
    /// @param _stakeAmount The amount of tokens staked
    /// @param _stakerAddress The address of the user who staked
    function _setStaker(uint _stakeAmount, address _stakerAddress, uint _stakeId, uint _silverNftId, uint _goldNftId) private {
        hasStaked[_stakerAddress] = true;
        if (_stakeAmount >= investorTreshholdAmount) {
            isInvestor[_stakerAddress] = true;
            activeStake[_stakerAddress] = ActiveStake(_stakeId, investorTreshholdAmount, block.timestamp, _silverNftId, _goldNftId);
            investors.push(_stakerAddress);
        }
        emit Staked(msg.sender, _stakeAmount, _stakeId);
    }

    /// @notice Unstakes a given stake by ID and updates related data
    function unstake(address _stakerAddress) private {
        ActiveStake storage stake = activeStake[msg.sender];

        if(stake.silverNftId != 0){
            nftBridged[stake.silverNftId] = false;
        } else if(stake.goldNftId != 0){
            goldNftBridged[stake.goldNftId] = false;
            removeInvestor(_stakerAddress);
        }
        activeStake[msg.sender] = ActiveStake(0,0,0,0,0);
    }

    function bridgeStakingAccess(uint16 _destChainId, bytes calldata _options, uint _silverNftId, uint _goldNftId) public payable {

        if(_goldNftId != 0){
            require(INFTContract(forcefiGoldNFTAddress).isOwnerOf(msg.sender, _goldNftId), "Not eligable to bridge access");
            require(!goldNftBridged[_goldNftId], "NFT already bridged");
            goldNftBridged[_goldNftId] = true;
        } else if(_silverNftId != 0) {
            require(INFTContract(forcefiSilverNFTAddress).isOwnerOf(msg.sender, _silverNftId), "Not eligable to bridge access");
            require(!nftBridged[_silverNftId], "NFT already bridged");
            nftBridged[_silverNftId] = true;
        }

        bytes memory payload = abi.encode(msg.sender, _silverNftId, _goldNftId);

        _lzSend(_destChainId, payload, _options, MessagingFee(msg.value, 0), payable(msg.sender));
    }
}
