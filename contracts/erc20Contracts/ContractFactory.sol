// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC20MintableBurnableToken.sol";
import "./ERC20BurnableToken.sol";
import "./ERC20MintableToken.sol";
import "./ERC20Token.sol";
import "./../ForcefiBaseContract.sol";

contract ContractFactory is ForcefiBaseContract {

    enum ContractType { StandardToken, Mintable, Burnable, MintableAndBurnable }

    event ContractCreated(address indexed contractAddress, address indexed deployer, string projectName);

    function createContract(ContractType _type, string memory _name, string memory _ticker, string memory _projectName, uint256 _initialSupply) external payable returns (address) {
        //        bool hasCreationToken = IForcefiPackage(forcefiPackageAddress).hasCreationToken(msg.sender, _projectName);
        //        require(msg.value == feeAmount || hasCreationToken, "Invalid fee value or no creation token available");
        address newContract;

        if (_type == ContractType.StandardToken) {
            newContract = address(new ERC20Token(_name, _ticker, _initialSupply));
        } else if (_type == ContractType.Mintable) {
            newContract = address(new ERC20MintableToken(_name, _ticker, _initialSupply));
        }
        else if (_type == ContractType.Burnable) {
            newContract = address(new ERC20BurnableToken(_name, _ticker, _initialSupply));
        }
        else if (_type == ContractType.MintableAndBurnable) {
            newContract = address(new ERC20MintableBurnableToken(_name, _ticker, _initialSupply));
        }
        else {
            revert("Invalid contract type");
        }

        emit ContractCreated(newContract, msg.sender, _projectName);
        return newContract;
    }

}
