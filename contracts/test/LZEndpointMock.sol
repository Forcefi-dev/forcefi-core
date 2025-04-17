// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

interface ILayerZeroEndpointV2Mock {
    struct MessagingFee {
        uint256 nativeFee;
        uint256 lzTokenFee;
    }

    struct MessagingReceipt {
        uint256 nonce;
        bytes32 guid;
    }

    struct SendInput {
        uint32 dstEid;
        bytes32 guid;
        bytes destination;
        bytes message;
        bytes options;
        bool payInLzToken;
        bytes adapterParams;
    }

    struct Origin {
        uint32 srcEid;
        address sender;
        uint64 nonce;
    }
}

contract LZEndpointMock is ERC165, ILayerZeroEndpointV2Mock {
    uint16 public immutable chainId;
    mapping(address => bool) public supportedContracts;

    event PacketSent(
        bytes32 guid,
        uint64 nonce,
        uint32 dstEid,
        address sender,
        bytes destination,
        bytes message
    );

    constructor(uint16 _chainId) {
        chainId = _chainId;
    }

    function quote(SendInput calldata, bytes calldata) external pure returns (MessagingFee memory, bytes memory) {
        return (MessagingFee(0, 0), "");
    }

    function send(
        SendInput calldata _params,
        bytes calldata,
        bytes calldata _options,
        address payable _refundAddr
    ) external payable returns (MessagingReceipt memory) {
        emit PacketSent(
            _params.guid,
            1,
            _params.dstEid,
            msg.sender,
            _params.destination,
            _params.message
        );
        return MessagingReceipt(1, _params.guid);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(ILayerZeroEndpointV2Mock).interfaceId || super.supportsInterface(interfaceId);
    }

    // Mock implementations for required interface methods
    function setLzToken(address) external {}
    function nativeFee(bytes calldata) external pure returns (uint256) { return 0; }
    function terminate(bytes32[] calldata) external {}
    function clear(bytes32[] calldata) external {}
    function verify(bytes32, address, uint256) external pure returns (bool) { return true; }
    function setDelegate(address) external {}
    function delegate(address) external view returns (address) { return address(0); }
    function initializable(address) external view returns (bool) { return true; }
}
