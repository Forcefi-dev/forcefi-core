// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "https://github.com/LayerZero-Labs/solidity-examples/blob/main/contracts/lzApp/NonblockingLzApp.sol";

contract LzReceiver is NonblockingLzApp {

    address public dfoMainWalletFactoryAddress;
    string public lastError;

    constructor(address _lzEndpoint) NonblockingLzApp(_lzEndpoint) {
    }

    function setDfoMainWalletFactoryAddress(address _dfoMainWalletFactoryAddress) public onlyOwner {
        dfoMainWalletFactoryAddress = _dfoMainWalletFactoryAddress;
    }

    function _nonblockingLzReceive(uint16, bytes memory, uint64, bytes memory _payload) internal override {
        (uint _amount, address _sender) = abi.decode(_payload, (uint, address));
        IDFOOption(dfoMainWalletFactoryAddress).safeMint(_sender, _amount);
    }

    function trustAddress(uint16 _destChainId, address _otherContract) public onlyOwner {
        trustedRemoteLookup[_destChainId] = abi.encodePacked(_otherContract, address(this));
    }
}

interface IDFOOption{
    function safeMint(address, uint) external;
    function safeMint2(address, uint) external;
}