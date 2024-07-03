// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./../../ForcefiBaseContract.sol";
import "./ERC20PausableMintableBurnableToken.sol";
import "./ERC20PausableBurnableToken.sol";
import "./ERC20PausableMintableToken.sol";
import "./ERC20PausableToken.sol";

contract PausableContractFactory is ForcefiBaseContract {

    enum ContractType { Pausable, PausableBurnable, PausableMintableBurnable, PausableMintable }

    event ContractCreated(address indexed contractAddress, address indexed deployer, string projectName);

    function createContract(ContractType _type, string memory _name, string memory _ticker, string memory _projectName, uint256 _initialSupply) external payable returns (address) {
//        bool hasCreationToken = IForcefiPackage(forcefiPackageAddress).hasCreationToken(msg.sender, _projectName);
//        require(msg.value == feeAmount || hasCreationToken, "Invalid fee value or no creation token available");
        address newContract;

        if (_type == ContractType.Pausable) {
            newContract = address(new ERC20PausableToken(_name, _ticker, _initialSupply));
        } else if (_type == ContractType.PausableMintable) {
            newContract = address(new ERC20PausableMintableToken(_name, _ticker, _initialSupply));
        }
        else if (_type == ContractType.PausableBurnable) {
            newContract = address(new ERC20PausableBurnableToken(_name, _ticker, _initialSupply));
        }
        else if (_type == ContractType.PausableMintableBurnable) {
            newContract = address(new ERC20PausableMintableBurnableToken(_name, _ticker, _initialSupply));
        }
        else {
            revert("Invalid contract type");
        }

        emit ContractCreated(newContract, msg.sender, _projectName);
        return newContract;
    }

}
