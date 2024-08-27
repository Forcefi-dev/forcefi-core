// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./ForcefiBaseContract.sol";
import "./VestingLibrary.sol";

/**
 * @title Vesting
 * @dev This contract manages token vesting plans for multiple beneficiaries within a project.
 * It allows for the creation of vesting plans, adding beneficiaries, and releasing vested tokens.
 * Inherits from the ForcefiBaseContract and uses OpenZeppelin's ERC20 and Counters utilities.
 */
contract VestingFinal is ForcefiBaseContract {

    using Counters for Counters.Counter;

    // Counter for generating unique vesting plan IDs
    Counters.Counter private _tokenIdCounter;

    // Mapping from project names to a list of vesting plan IDs
    mapping(string => bytes32[]) public projectVestings;

    // Mapping from vesting plan IDs to their corresponding VestingPlan struct
    mapping(bytes32 => VestingPlan) public vestingPlans;

    // Mapping from vesting plan IDs and beneficiary addresses to their IndividualVesting details
    mapping(bytes32 => mapping(address => IndividualVesting)) public individualVestings;

    // Struct representing a beneficiary with an address and token amount
    struct Benificiar {
        /**
         * @param beneficiarAddress The address of the beneficiary who will receive tokens.
     * @param tokenAmount The total amount of tokens allocated to the beneficiary.
     */
        address beneficiarAddress;
        uint tokenAmount;
    }

    // Struct representing a vesting plan
    struct VestingPlan {
        /**
        * @param tokenAddress The address of the ERC20 token that will be vested.
     * @param projectName The name of the project associated with this vesting plan.
     * @param label A label for this specific vesting plan.
     * @param vestingOwner The address of the owner of the vesting plan.
     * @param saleStart The timestamp indicating when the vesting starts.
     * @param cliffPeriod The duration (in seconds) before the tokens start vesting.
     * @param vestingPeriod The total duration (in seconds) over which the tokens will be vested.
     * @param releasePeriod The period (in seconds) how often tokens are released after the cliff period.
     * @param tgePercent The percentage of the total tokens to be released at the token generation event (TGE).
     * @param totalTokenAmount The total amount of tokens allocated for this vesting plan.
     * @param tokenAllocated The amount of tokens that have already been allocated to beneficiaries.
     * @param initialized A boolean indicating whether the vesting plan has been initialized.
     */
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

    // Struct representing an individual beneficiary's vesting details
    struct IndividualVesting {
        /**
        * @param tokenAmount The total amount of tokens allocated to the individual beneficiary.
     * @param tokensReleased The amount of tokens that have already been released to the beneficiary.
     * @param initialized A boolean indicating whether the vesting for this beneficiary has been initialized.
     * @param initializedTimestamp The timestamp when the vesting was initialized for this beneficiary.
     */
        uint tokenAmount;
        uint tokensReleased;
        bool initialized;
        uint initializedTimestamp;
    }

    // Struct representing the parameters required to create a new vesting plan
    struct VestingPlanParams {
        /**
        * @param benificiars An array of Benificiar structs representing each beneficiary and their token allocation.
     * @param vestingPlanLabel A label for the vesting plan being created.
     * @param saleStart The timestamp indicating when the vesting period begins.
     * @param cliffPeriod The duration (in seconds) before the tokens start vesting.
     * @param vestingPeriod The total duration (in seconds) over which the tokens will be vested.
     * @param releasePeriod The period (in seconds) for how often tokens are released after the cliff period.
     * @param tgePercent The percentage of the total tokens to be released at the token generation event (TGE).
     * @param totalTokenAmount The total amount of tokens to be allocated for the vesting plan.
     */
        Benificiar[] benificiars;
        string vestingPlanLabel;
        uint saleStart;
        uint cliffPeriod;
        uint vestingPeriod;
        uint releasePeriod;
        uint tgePercent;
        uint totalTokenAmount;
    }

    // Event emitted when beneficiaries are added to a vesting plan
    event AddedBenificiars(Benificiar[] beneficiaries, bytes32 indexed vestingIdx);

    constructor() {
    }

    /**
     * @dev Adds multiple vesting plans in bulk.
     * Transfers the total token amount for each vesting plan from the sender to the contract.
     *
     * @param vestingPlanParams Array of vesting plan parameters to be added.
     * @param _projectName Name of the project for which the vesting plans are being added.
     * @param _tokenAddress Address of the ERC20 token to be vested.
     */
    function addVestingPlansBulk(VestingPlanParams[] calldata vestingPlanParams, string calldata _projectName, address _tokenAddress) external payable {
        for (uint i = 0; i < vestingPlanParams.length; i++) {
            addVestingPlan(vestingPlanParams[i], _projectName, _tokenAddress);
        }
    }

    /**
     * @dev Internal function to add a single vesting plan.
     * Transfers the total token amount from the sender to the contract.
     *
     * @param params Vesting plan parameters.
     * @param _projectName Name of the project for which the vesting plan is being added.
     * @param _tokenAddress Address of the ERC20 token to be vested.
     */
    function addVestingPlan(VestingPlanParams memory params, string calldata _projectName, address _tokenAddress) internal {
        ERC20(_tokenAddress).transferFrom(msg.sender, address(this), params.totalTokenAmount);

        uint vestingIdx = _tokenIdCounter.current();
        _tokenIdCounter.increment();

        bytes32 UUID = VestingLibrary.generateUUID(vestingIdx);

        vestingPlans[UUID] = VestingPlan({
            tokenAddress: _tokenAddress,
            projectName: _projectName,
            label: params.vestingPlanLabel,
            vestingOwner: msg.sender,
            saleStart: params.saleStart,
            cliffPeriod: params.cliffPeriod,
            vestingPeriod: params.vestingPeriod,
            releasePeriod: params.releasePeriod,
            tgePercent: params.tgePercent,
            totalTokenAmount: params.totalTokenAmount,
            tokenAllocated: 0,
            initialized: true
        });

        addVestingBeneficiar(UUID, params.benificiars);
        projectVestings[_projectName].push(UUID);
    }

    /**
     * @dev Adds beneficiaries to a vesting plan.
     * Can only be called by the owner of the vesting plan.
     *
     * @param _vestingIdx The ID of the vesting plan.
     * @param _benificiars Array of beneficiaries to be added.
     */
    function addVestingBeneficiar(bytes32 _vestingIdx, Benificiar[] memory _benificiars) public {
        require(vestingPlans[_vestingIdx].initialized, "Invalid vesting plan");
        require(vestingPlans[_vestingIdx].vestingOwner == msg.sender, "Only vesting owner can add beneficiar");

        for (uint i = 0; i < _benificiars.length; i++) {
            require(
                vestingPlans[_vestingIdx].tokenAllocated + _benificiars[i].tokenAmount <=
                vestingPlans[_vestingIdx].totalTokenAmount,
                "Token allocation reached maximum for vesting plan"
            );

            IndividualVesting storage individualVesting = individualVestings[_vestingIdx][_benificiars[i].beneficiarAddress];
            individualVesting.initialized = true;
            individualVesting.tokenAmount += _benificiars[i].tokenAmount;
            vestingPlans[_vestingIdx].tokenAllocated += _benificiars[i].tokenAmount;
        }

        emit AddedBenificiars(_benificiars, _vestingIdx);
    }

    /**
     * @dev Withdraws unallocated tokens from a vesting plan.
     * Can only be called by the owner of the vesting plan.
     *
     * @param _vestingIdx The ID of the vesting plan.
     */
    function withdrawUnallocatedTokens(bytes32 _vestingIdx) public {
        require(vestingPlans[_vestingIdx].initialized, "Invalid vesting plan");
        require(vestingPlans[_vestingIdx].vestingOwner == msg.sender, "Only vesting owner can withdraw tokens");

        uint256 unallocatedTokens = vestingPlans[_vestingIdx].totalTokenAmount - vestingPlans[_vestingIdx].tokenAllocated;
        ERC20(vestingPlans[_vestingIdx].tokenAddress).transfer(msg.sender, unallocatedTokens);
        vestingPlans[_vestingIdx].totalTokenAmount = vestingPlans[_vestingIdx].tokenAllocated;
    }

    /**
     * @dev Releases vested tokens for the caller's individual vesting plan.
     * Transfers the releasable tokens to the caller.
     *
     * @param _vestingIdx The ID of the vesting plan.
     */
    function releaseVestedTokens(bytes32 _vestingIdx) public {
        uint256 vestedAmount = calculateVestedTokens(_vestingIdx);
        require(vestedAmount > 0, "TokenVesting: cannot release tokens, no vested tokens");

        IndividualVesting storage individualVesting = individualVestings[_vestingIdx][msg.sender];
        individualVesting.tokensReleased += vestedAmount;

        ERC20(vestingPlans[_vestingIdx].tokenAddress).transfer(msg.sender, vestedAmount);
    }

    /**
     * @dev Calculates the amount of vested tokens that can be released for the caller.
     *
     * @param _vestingIdx The ID of the vesting plan.
     * @return uint256 The amount of vested tokens that can be released.
     */
    function calculateVestedTokens(bytes32 _vestingIdx) public view returns (uint256) {
        VestingPlan memory vestingPlan = vestingPlans[_vestingIdx];
        IndividualVesting storage individualVesting = individualVestings[_vestingIdx][msg.sender];
        return VestingLibrary.computeReleasableAmount(
            vestingPlan.saleStart,
            vestingPlan.vestingPeriod,
            vestingPlan.releasePeriod,
            vestingPlan.cliffPeriod,
            vestingPlan.tgePercent,
            individualVesting.tokenAmount,
            individualVesting.tokensReleased
        );
    }

    /**
     * @dev Returns all vesting plan IDs for a given project.
     *
     * @param projectName The name of the project.
     * @return bytes32[] An array of vesting plan IDs associated with the project.
     */
    function getVestingsForProject(string memory projectName) public view returns (bytes32[] memory) {
        return projectVestings[projectName];
    }
}
