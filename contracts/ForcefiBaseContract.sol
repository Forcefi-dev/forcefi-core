// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

interface IForcefiPackage {
    function hasCreationToken(address, string memory) external view returns(bool);
}

contract ForcefiBaseContract is Ownable {

    uint public feeAmount;
    address public forcefiPackageAddress;

    constructor() {
    }

    function setFeeAmount(uint _feeAmount) public onlyOwner {
        feeAmount = _feeAmount;
    }

    function setForcefiPackageAddress(address _forcefiPackageAddress) public onlyOwner {
        forcefiPackageAddress = _forcefiPackageAddress;
    }
}
