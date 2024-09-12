// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@layerzerolabs/solidity-examples/contracts/lzApp/NonblockingLzApp.sol";

contract ForcefiChildChainStaking is Ownable, NonblockingLzApp {

    uint private constant ELIGABILITY_TIME = 2629800;

    address private lzContractAddress;
    mapping(address => ActiveStake) public activeStake;
    address[] public investors;

    uint public minStakingAmount;
    uint public investorTreshholdAmount;

    struct ActiveStake{
        address stakerAddress;
        uint stakeAmount;
        uint stakeEventTimestamp;
    }

    constructor(address _lzContractAddress) Ownable(tx.origin) NonblockingLzApp(_lzContractAddress) {
        lzContractAddress = _lzContractAddress;
    }

    function setMinStakingAmount(uint _stakingAmount) external onlyOwner {
        minStakingAmount = _stakingAmount;
    }

    function setInvestorTreshholdAmount(uint _investorTreshholdAmount) external onlyOwner {
        investorTreshholdAmount = _investorTreshholdAmount;
    }

    function _nonblockingLzReceive(uint16, bytes memory, uint64, bytes memory _payload) internal override {
        (address _staker, uint _stakeAmount) = abi.decode(_payload, (address, uint));
        if(_stakeAmount > 0){
            _setStaker(_stakeAmount, _staker);
        } else unstake();
    }

    function receiveFees(address _feeTokenAddress, uint256 _feeAmount) public {
        uint256 totalEligibleStake = 0;
        uint256[] memory eligibleStakes = new uint256[](investors.length);
        address[] memory eligibleFeeReceivers = new address[](investors.length);
        uint256 count = 0;

        // Calculate total eligible stake and store eligible receivers
        for (uint256 i = 0; i < investors.length; i++) {
            if (activeStake[investors[i]].stakeEventTimestamp + ELIGABILITY_TIME < block.timestamp) {
                eligibleFeeReceivers[count] = investors[i];
                eligibleStakes[count] = activeStake[investors[i]].stakeAmount;
                totalEligibleStake += activeStake[investors[i]].stakeAmount;
                count++;
            }
        }

        require(totalEligibleStake > 0, "No eligible stakes");

        // Distribute the fees proportionally based on stake amount
        for (uint256 j = 0; j < count; j++) {
            uint256 stakeAmount = eligibleStakes[j];
            uint256 feeShare = (_feeAmount * stakeAmount) / totalEligibleStake;
            IERC20(_feeTokenAddress).transfer(eligibleFeeReceivers[j], feeShare);
        }
    }

    function _setStaker(uint _stakeAmount, address _stakerAddress) private {
        activeStake[msg.sender] = ActiveStake(_stakerAddress, _stakeAmount, block.timestamp);
        if(_stakeAmount + activeStake[msg.sender].stakeAmount >= investorTreshholdAmount) {
            investors.push(msg.sender);
        }
    }

    function unstake() private {
        activeStake[msg.sender].stakeAmount = 0;
        removeInvestor(msg.sender);
    }

    function removeInvestor(address investor) public onlyOwner {
        uint index = findInvestorIndex(investor);
        require(index < investors.length, "Investor not found");

        for (uint i = index; i < investors.length - 1; i++) {
            investors[i] = investors[i + 1];
        }
        investors.pop();
    }

    function findInvestorIndex(address investor) internal view returns (uint) {
        for (uint i = 0; i < investors.length; i++) {
            if (investors[i] == investor) {
                return i;
            }
        }
        revert("Investor not found");
    }

    function getInvestors() public view returns (address[] memory) {
        return investors;
    }

    function hasStaked() public view returns(bool) {
        return activeStake[msg.sender].stakeAmount >= minStakingAmount;
    }

}
