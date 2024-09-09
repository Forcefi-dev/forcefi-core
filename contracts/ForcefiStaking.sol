// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
//import "https://github.com/LayerZero-Labs/solidity-examples/blob/main/contracts/lzApp/NonblockingLzApp.sol";

contract ForcefiStaking is Ownable {

    uint _stakeIdCounter;

    uint public eligabilityTime;
    FeeMultiplier public feeMultiplier;

    address private lzContractAddress;
    address public forcefiTokenAddress;
    address public forcefiFundraisingAddress;
    mapping(uint => ActiveStake) public activeStake;
    uint256[] public investors;

    uint16 [] public chainList;

    mapping(uint => address) public silverNftOwner;
    mapping(uint => address) public goldNftOwner;
    mapping(address => bool) public isCurator;
    mapping(address => mapping(address => uint)) public investorTokenBalance;

    uint public minStakingAmount;
    uint public curatorTreshholdAmount;
    uint public investorTreshholdAmount;

    address public silverNftContract;
    address public goldNftContract;

    struct ActiveStake{
        uint stakeId;
        address stakerAddress;
        uint stakeAmount;
        uint stakeEventTimestamp;
        uint goldNftId;
    }

    struct FeeMultiplier{
        uint256 eligibleToReceiveFee;
        uint256 beginnerFeeThreshold;
        uint256 intermediateFeeThreshold;
        uint256 maximumFeeThreshold;
        uint256 beginnerMultiplier;
        uint256 intermediateMultiplier;
        uint256 maximumMultiplier;
    }

    event Staked(address indexed stakerAddress, uint amount, uint indexed stakeIdx);
    event Unstaked(address indexed stakerAddress, uint indexed stakeIdx);

//    constructor(address _lzContractAddress, address _silverNftAddress, address _goldNftAddress) NonblockingLzApp(_lzContractAddress) {
//        silverNftContract = _silverNftAddress;
//        goldNftContract = _goldNftAddress;
//        lzContractAddress = _lzContractAddress;
//    }

    constructor(address _silverNftAddress, address _goldNftAddress, address _forcefiTokenAddress, address _forcefiFundraisingAddress) Ownable(tx.origin) {
        silverNftContract = _silverNftAddress;
        goldNftContract = _goldNftAddress;
        forcefiTokenAddress = _forcefiTokenAddress;
        forcefiFundraisingAddress = _forcefiFundraisingAddress;

        feeMultiplier = FeeMultiplier(
            2629800,
            2629800 * 3,
            2629800 * 6,
            2629800 * 9,
            10,
            20,
            30
        );
    }

    function setFeeMultiplier(uint _eligableToReceiveFee, uint _beginnerFeeTreshold, uint _intermediateFeeTreshold, uint _maximumFeeTreshold, uint _beginnerMultiplier, uint _intermediateMultiplier, uint _maximumMultiplier) public onlyOwner {
        feeMultiplier = FeeMultiplier(_eligableToReceiveFee, _beginnerFeeTreshold, _intermediateFeeTreshold, _maximumFeeTreshold, _beginnerMultiplier, _intermediateMultiplier, _maximumMultiplier);
    }

//    function setEligabilityTime(uint _eligabilityTime) external onlyOwner {
//        eligabilityTime = _eligabilityTime;
//    }

    function setMinStakingAmount(uint _stakingAmount) external onlyOwner {
        minStakingAmount = _stakingAmount;
    }

    function setCuratorTreshholdAmount(uint _curatorTreshholdAmount) external onlyOwner {
        curatorTreshholdAmount = _curatorTreshholdAmount;
    }

    function setInvestorTreshholdAmount(uint _investorTreshholdAmount) external onlyOwner {
        investorTreshholdAmount = _investorTreshholdAmount;
    }

//    function _nonblockingLzReceive(uint16, bytes memory, uint64, bytes memory _payload) internal override {
//        // No logic to implement
//    }

    function bridgeStakingAccess(uint16[] memory _destChainIds, uint gasForDestinationLzReceive, uint _stakeId) public payable {
        require(activeStake[_stakeId].stakerAddress == msg.sender, "Not an owner of a stake");
        // Check if user eligibility to bridge
        require(hasStaked(_stakeId), "Sender doesn't have active stake");

        bytes memory payload = abi.encode(msg.sender, activeStake[_stakeId].stakeAmount);
//        executeBridge(_destChainIds, payload, gasForDestinationLzReceive);
    }

    function bridgeNftToken(uint16[] memory _destChainIds, uint gasForDestinationLzReceive, uint _nftId, uint _stakeId) public payable {
        // Check if user eligibility to bridge
        require(hasStaked(_stakeId), "Sender doesn't have active stake");

        // Calc stake amount
        uint stakeAmount;
        if (IERC20(goldNftContract).balanceOf(msg.sender) >= 1 && (silverNftOwner[_nftId] == address(0) || silverNftOwner[_nftId] == msg.sender)) {
            stakeAmount = investorTreshholdAmount;
            silverNftOwner[_nftId] = msg.sender;
        } else if (IERC20(silverNftContract).balanceOf(msg.sender) >= 1 && (goldNftOwner[_nftId] == address(0)|| goldNftOwner[_nftId] == msg.sender)) {
            stakeAmount = minStakingAmount;
            goldNftOwner[_nftId] = msg.sender;
        }

        bytes memory payload = abi.encode(msg.sender, activeStake[_stakeId].stakeAmount);
//        executeBridge(_destChainIds, payload, gasForDestinationLzReceive);
    }

//    function executeBridge(uint16[] memory _destChainIds, bytes memory payload, uint gasForDestinationLzReceive) internal {
//        uint16 version = 1;
//        bytes memory adapterParams = abi.encodePacked(version, gasForDestinationLzReceive);
//        for (uint256 i = 0; i < _destChainIds.length; i++) {
//            _lzSend(_destChainIds[i], payload, payable(tx.origin), address(0x0), adapterParams, msg.value);
//        }
//    }

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

        if(count > 0) {
            IERC20(_feeTokenAddress).transferFrom(forcefiFundraisingAddress, address(this), _feeAmount);

            for (uint256 j = 0; j < count; j++) {
                uint256 stakeAmount = eligibleStakes[j];
                uint256 feeShare = _feeAmount * stakeAmount / tokensWithMultiplier ;

                investorTokenBalance[eligibleFeeReceivers[j]][_feeTokenAddress] += feeShare;
            }
        }
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

    function stake(uint _stakeAmount, uint _goldNftId) public {
        require(_stakeAmount >= minStakingAmount || _goldNftId != 0, "Not enough FORC tokens to stake");
        if(_goldNftId != 0 && goldNftOwner[_goldNftId] == address(0)){
            goldNftOwner[_goldNftId] = msg.sender;
            _setStaker(investorTreshholdAmount, msg.sender, _goldNftId);
        } else {
            ERC20(forcefiTokenAddress).transferFrom(msg.sender, address(this), _stakeAmount);
            _setStaker(_stakeAmount, msg.sender, 0);
        }
    }

    function _setStaker(uint _stakeAmount, address _stakerAddress, uint _goldNftId) private {
        uint stakeId = _stakeIdCounter;
        _stakeIdCounter += 1;
        activeStake[stakeId] = ActiveStake(stakeId, _stakerAddress, _stakeAmount, block.timestamp, _goldNftId);
        if(_stakeAmount >= curatorTreshholdAmount){
            isCurator[msg.sender] = true;
        }
        if(_stakeAmount >= investorTreshholdAmount) {
            investors.push(stakeId);
        }
        emit Staked(msg.sender, _stakeAmount, stakeId);
    }

    function unstake(uint _stakeId, uint gasForDestinationLzReceive) public {
        require(activeStake[_stakeId].goldNftId == 0, "Can't unstake gold nft");
        uint stakeAmount = activeStake[_stakeId].stakeAmount;
        activeStake[_stakeId].stakeAmount = 0;
        ERC20(forcefiTokenAddress).transfer(msg.sender, stakeAmount);
        isCurator[msg.sender] = false;
        removeInvestor(_stakeId);
//        bridgeStakingAccess(chainList, gasForDestinationLzReceive);
        emit Unstaked(msg.sender, _stakeId);
    }

    function removeInvestor(uint investor) public onlyOwner {
        uint index = findInvestorIndex(investor);
        require(index < investors.length, "Investor not found");

        for (uint i = index; i < investors.length - 1; i++) {
            investors[i] = investors[i + 1];
        }
        investors.pop();
    }

    function findInvestorIndex(uint investor) internal view returns (uint) {
        for (uint i = 0; i < investors.length; i++) {
            if (investors[i] == investor) {
                return i;
            }
        }
        revert("Investor not found");
    }

    function getInvestors() public view returns (uint[] memory) {
        return investors;
    }

    function hasStaked(uint _stakeId) public view returns(bool) {
        return activeStake[_stakeId].stakeAmount >= minStakingAmount;
//        return activeStake[msg.sender].stakeAmount >= minStakingAmount || IERC20(silverNftContract).balanceOf(msg.sender) >= 1 || IERC20(goldNftContract).balanceOf(msg.sender) >= 1;
    }

}
