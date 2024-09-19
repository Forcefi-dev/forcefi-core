// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@layerzerolabs/solidity-examples/contracts/lzApp/NonblockingLzApp.sol";

abstract contract BaseStaking is Ownable, NonblockingLzApp {
    uint internal _stakeIdCounter;

    FeeMultiplier public feeMultiplier;
    address private forcefiFundraisingAddress;

    mapping(uint => ActiveStake) public activeStake;
    mapping(address => mapping(address => uint)) public investorTokenBalance;
    mapping(address => uint[]) public userStakes;
    uint256[] public investors;

    uint public investorTreshholdAmount;

    struct ActiveStake {
        uint stakeId;
        address stakerAddress;
        uint stakeAmount;
        uint stakeEventTimestamp;
        uint goldNftId;
    }

    struct FeeMultiplier {
        uint256 eligibleToReceiveFee;
        uint256 earlyUnstakePercent;
        uint256 beginnerFeeThreshold;
        uint256 intermediateFeeThreshold;
        uint256 maximumFeeThreshold;
        uint256 beginnerMultiplier;
        uint256 intermediateMultiplier;
        uint256 maximumMultiplier;
    }

    event Staked(address indexed stakerAddress, uint amount, uint indexed stakeIdx);
    event Unstaked(address indexed stakerAddress, uint indexed stakeIdx);

    constructor(address _forcefiFundraisingAddress, address _lzContractAddress) NonblockingLzApp(_lzContractAddress) Ownable(tx.origin) {
        forcefiFundraisingAddress = _forcefiFundraisingAddress;

        feeMultiplier = FeeMultiplier(
            2629800,
            100,
            2629800 * 3,
            2629800 * 6,
            2629800 * 9,
            10,
            20,
            30
        );
    }

    function receiveFees(address _feeTokenAddress, uint256 _feeAmount) public {
        uint256 totalEligibleStake = 0;
        uint256[] memory eligibleStakes = new uint256[](investors.length);
        address[] memory eligibleFeeReceivers = new address[](investors.length);
        uint256 count = 0;

        uint256 tokensWithMultiplier = 0;

        for (uint256 i = 0; i < investors.length; i++) {
            if (activeStake[investors[i]].stakeEventTimestamp + feeMultiplier.eligibleToReceiveFee < block.timestamp) {
                uint256 stakingTime = block.timestamp - activeStake[investors[i]].stakeEventTimestamp;
                uint256 multiplier = getMultiplier(stakingTime);

                uint256 activeStakeMultiplied = multiplier * activeStake[investors[i]].stakeAmount;
                tokensWithMultiplier += activeStakeMultiplied;

                eligibleFeeReceivers[count] = activeStake[investors[i]].stakerAddress;
                eligibleStakes[count] = activeStakeMultiplied;
                count++;
            }
        }

        if (count > 0) {
            IERC20(_feeTokenAddress).transferFrom(forcefiFundraisingAddress, address(this), _feeAmount);

            for (uint256 j = 0; j < count; j++) {
                uint256 stakeAmount = eligibleStakes[j];
                uint256 feeShare = (_feeAmount * stakeAmount) / tokensWithMultiplier;

                investorTokenBalance[eligibleFeeReceivers[j]][_feeTokenAddress] += feeShare;
            }
        }
    }

    function setFeeMultiplier(
        uint _eligibleToReceiveFee,
        uint _earlyUnstakePercent,
        uint _beginnerFeeThreshold,
        uint _intermediateFeeThreshold,
        uint _maximumFeeThreshold,
        uint _beginnerMultiplier,
        uint _intermediateMultiplier,
        uint _maximumMultiplier
    ) public onlyOwner {
        feeMultiplier = FeeMultiplier(
            _eligibleToReceiveFee,
            _earlyUnstakePercent,
            _beginnerFeeThreshold,
            _intermediateFeeThreshold,
            _maximumFeeThreshold,
            _beginnerMultiplier,
            _intermediateMultiplier,
            _maximumMultiplier
        );
    }

    function getMultiplier(uint256 stakingTime) internal view returns (uint256) {
        if (stakingTime >= feeMultiplier.maximumFeeThreshold) {
            return 100 + feeMultiplier.maximumMultiplier;
        } else if (stakingTime >= feeMultiplier.intermediateFeeThreshold) {
            return 100 + feeMultiplier.intermediateMultiplier;
        } else if (stakingTime >= feeMultiplier.beginnerFeeThreshold) {
            return 100 + feeMultiplier.beginnerMultiplier;
        } else {
            return 100;
        }
    }

    function claimFees(address _feeTokenAddress) external {
        uint tokenBalance = investorTokenBalance[msg.sender][_feeTokenAddress];
        IERC20(_feeTokenAddress).transfer(msg.sender, tokenBalance);
        investorTokenBalance[msg.sender][_feeTokenAddress] = 0;
    }

    function getBalance(address _investor, address _token) public view returns (uint) {
        return investorTokenBalance[_investor][_token];
    }

    function setInvestorTreshholdAmount(uint _investorTreshholdAmount) external onlyOwner {
        investorTreshholdAmount = _investorTreshholdAmount;
    }

    function removeInvestor(uint investorId) internal {
        uint index = findInvestorIndex(investorId);
        require(index < investors.length, "Investor not found");

        for (uint i = index; i < investors.length - 1; i++) {
            investors[i] = investors[i + 1];
        }
        investors.pop();
    }

    function findInvestorIndex(uint investorId) internal view returns (uint) {
        for (uint i = 0; i < investors.length; i++) {
            if (investors[i] == investorId) {
                return i;
            }
        }
        revert("Investor not found");
    }

    function getInvestors() public view returns (uint[] memory) {
        return investors;
    }


    // Helper function to remove a stakeId from the user's stakes
    function removeStakeFromUser(address _user, uint _stakeId) internal {
        uint[] storage stakes = userStakes[_user];
        for (uint i = 0; i < stakes.length; i++) {
            if (stakes[i] == _stakeId) {
                stakes[i] = stakes[stakes.length - 1];
                stakes.pop();
                break;
            }
        }
    }

    // Function to check if a user has active stakes
    function hasStaked(address _stakerAddress) public view returns (bool) {
        uint[] memory stakes = userStakes[_stakerAddress];

        for (uint i = 0; i < stakes.length; i++) {
            uint stakeId = stakes[i];
            if (activeStake[stakeId].stakeAmount > 0) {
                return true;
            }
        }
        return false;
    }
}
