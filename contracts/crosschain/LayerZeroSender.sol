// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "https://github.com/LayerZero-Labs/solidity-examples/blob/main/contracts/lzApp/NonblockingLzApp.sol";

contract LayerZeroSender is NonblockingLzApp {

    uint16 public destChainId;

    address public dfoAddress;

    constructor(address _lzEndpoint, uint16 _destChainId) NonblockingLzApp(_lzEndpoint) {
        destChainId = _destChainId;
    }

    function setDfoAddress(address _dfoAddress) public onlyOwner {
        dfoAddress = _dfoAddress;
    }

    function _nonblockingLzReceive(uint16, bytes memory, uint64, bytes memory _payload) internal override {}

    function send(uint _amount, address _sender, uint gasForDestinationLzReceive) public payable {
        require(msg.sender == dfoAddress, "Invalid sender address");
        bytes memory payload = abi.encode(_amount, _sender);
        uint16 version = 1;
        bytes memory adapterParams = abi.encodePacked(version, gasForDestinationLzReceive);
        _lzSend(destChainId, payload, payable(tx.origin), address(0x0), adapterParams, msg.value);
    }

    function trustAddress(uint16 _destChainId, address _otherContract) public onlyOwner {
        trustedRemoteLookup[_destChainId] = abi.encodePacked(_otherContract, address(this));
    }
}
