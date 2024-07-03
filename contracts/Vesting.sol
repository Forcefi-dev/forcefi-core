// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./ForcefiBaseContract.sol";
import "./VestingLibrary.sol";

contract VestingFinal is ForcefiBaseContract {

    using Counters for Counters.Counter;
    Counters.Counter _tokenIdCounter;

    mapping(string => bytes32[]) projectVestings;
    mapping(bytes32 => VestingPlan) public vestingPlans;
    mapping(bytes32 => mapping(address => IndividualVesting)) public individualVestings;

    struct Benificiar {
        address beneficiarAddress;
        uint tokenAmount;
    }

    struct VestingPlan {
        address tokenAddress;
        string projectName;
        string label;
        address vestingOwner;
        uint saleStart;
        uint cliffPeriod;
        uint vestingPeriod;
        uint releasePeriod;
        uint tgePercent;
        uint totalTokenAmount;
        uint tokenAllocated;
        bool initialized;
    }

    struct IndividualVesting {
        uint tokenAmount;
        uint tokensReleased;
        bool initialized;
        uint initializedTimestamp;
    }

    struct VestingPlanParams {
        Benificiar[] benificiars;
        string vestingPlanLabel;
        uint saleStart;
        uint cliffPeriod;
        uint vestingPeriod;
        uint releasePeriod;
        uint tgePercent;
        uint totalTokenAmount;
    }

    event AddedBenificiars(Benificiar [] beneficiaries);

    constructor() {

    }

    function addVestingPlansBulk(VestingPlanParams[] calldata vestingPlanParams, string calldata _projectName, address _tokenAddress) external payable {
        bool hasCreationToken = IForcefiPackage(forcefiPackageAddress).hasCreationToken(msg.sender, _projectName);
        require(msg.value == feeAmount || hasCreationToken, "Invalid fee value or no creation token available");
        for (uint i = 0; i < vestingPlanParams.length; i++) {
            addVestingPlan(vestingPlanParams[i], _projectName, _tokenAddress);
        }
    }

    function addVestingPlan(VestingPlanParams memory params, string calldata _projectName, address _tokenAddress) internal {
        ERC20(_tokenAddress).transferFrom(msg.sender, address(this), params.totalTokenAmount);

        uint vestingIdx = _tokenIdCounter.current();
        _tokenIdCounter.increment();

        bytes32 UUID = VestingLibrary.generateUUID(vestingIdx);

        vestingPlans[UUID] = VestingPlan(_tokenAddress, _projectName, params.vestingPlanLabel, msg.sender, params.saleStart, params.cliffPeriod, params.vestingPeriod, params.releasePeriod, params.tgePercent, params.totalTokenAmount, 0, true);
        addVestingBeneficiar(UUID, params.benificiars);
        projectVestings[_projectName].push(UUID);
    }

    function addVestingBeneficiar(bytes32 _vestingIdx, Benificiar [] memory _benificiars) public{
        require(vestingPlans[_vestingIdx].initialized, "Invalid vesting plan");
        require(vestingPlans[_vestingIdx].vestingOwner == msg.sender, "Only vesting owner can add beneficiar");
        for(uint i =0 ; i < _benificiars.length; i++){
            require(vestingPlans[_vestingIdx].tokenAllocated + _benificiars[i].tokenAmount <= vestingPlans[_vestingIdx].totalTokenAmount, "Token allocation reached maximum for vesting plan");
            IndividualVesting storage individualVesting = individualVestings[_vestingIdx][_benificiars[i].beneficiarAddress];
            individualVesting.initialized = true;
            individualVesting.tokenAmount += _benificiars[i].tokenAmount;
            vestingPlans[_vestingIdx].tokenAllocated += _benificiars[i].tokenAmount;
        }
        emit AddedBenificiars(_benificiars);
    }

    function withdrawUnallocatedTokens(bytes32 _vestingIdx) public {
        require(vestingPlans[_vestingIdx].initialized, "Invalid vesting plan");
        require(vestingPlans[_vestingIdx].vestingOwner == msg.sender, "Only vesting owner can add beneficiar");

        uint256 unallocatedTokens = vestingPlans[_vestingIdx].totalTokenAmount - vestingPlans[_vestingIdx].tokenAllocated;
        ERC20(vestingPlans[_vestingIdx].tokenAddress).transfer(msg.sender, unallocatedTokens);
        vestingPlans[_vestingIdx].totalTokenAmount = vestingPlans[_vestingIdx].tokenAllocated;
    }

    function releaseVestedTokens(bytes32 _vestingIdx) public {
        uint256 vestedAmount = calculateVestedTokens(_vestingIdx);
        require(vestedAmount > 0, "TokenVesting: cannot release tokens, no vested tokens");

        IndividualVesting storage individualVesting = individualVestings[_vestingIdx][msg.sender];
        individualVesting.tokensReleased += vestedAmount;

        ERC20(vestingPlans[_vestingIdx].tokenAddress).transfer(msg.sender, vestedAmount);
    }

    function getTime() public view returns (uint) {
        return block.timestamp;
    }

    function calculateVestedTokens(bytes32 _vestingIdx) public view returns (uint256) {
        VestingPlan memory vestingPlan = vestingPlans[_vestingIdx];

        IndividualVesting storage individualVesting = individualVestings[_vestingIdx][msg.sender];
        return VestingLibrary.computeReleasableAmount(vestingPlan.saleStart, vestingPlan.vestingPeriod, vestingPlan.releasePeriod, vestingPlan.cliffPeriod, vestingPlan.tgePercent, individualVesting.tokenAmount, individualVesting.tokensReleased);

    }

    function getVestingsForProject(string memory projectName) public view returns (bytes32[] memory) {
        return projectVestings[projectName];
    }
}
