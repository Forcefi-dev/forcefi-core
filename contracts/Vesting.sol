// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./ForcefiBaseContract.sol";
import "./VestingLibrary.sol";

/**
 * @title Vesting
 * @dev This contract manages token vesting plans for multiple beneficiaries within a project.
 * It allows for the creation of vesting plans, adding beneficiaries, and releasing vested tokens.
 * Inherits from ForcefiBaseContract, uses OpenZeppelin's ERC20 and SafeERC20, and includes reentrancy protection.
 */
contract Vesting is ForcefiBaseContract, ReentrancyGuard {
    using SafeERC20 for ERC20;

    uint256 private _tokenIdCounter;

    // Mapping from project names to a list of vesting plan IDs
    mapping(string => bytes32[]) public projectVestings;

    // Mapping from vesting plan IDs to their corresponding VestingPlan struct
    mapping(bytes32 => VestingPlan) public vestingPlans;

    // Mapping from vesting plan IDs and beneficiary addresses to their IndividualVesting details
    mapping(bytes32 => mapping(address => IndividualVesting)) public individualVestings;

    // Struct representing a beneficiary with an address and token amount
    struct Beneficiary {
        address beneficiaryAddress;
        uint tokenAmount;
    }

    // Struct representing a vesting plan
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

    // Struct representing an individual beneficiary's vesting details
     /**
     * @param tokenAmount The total amount of tokens allocated to the individual beneficiary.
     * @param tokensReleased The amount of tokens that have already been released to the beneficiary.
     * @param initialized A boolean indicating whether the vesting for this beneficiary has been initialized.
     * @param initializedTimestamp The timestamp when the vesting was initialized for this beneficiary.
     */
    struct IndividualVesting {
        uint tokenAmount;
        uint tokensReleased;
        bool initialized;
        uint initializedTimestamp;
    }

    // Struct representing the parameters required to create a new vesting plan
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
    struct VestingPlanParams {
        Beneficiary[] beneficiaries;
        string vestingPlanLabel;
        uint saleStart;
        uint cliffPeriod;
        uint vestingPeriod;
        uint releasePeriod;
        uint tgePercent;
        uint totalTokenAmount;
    }

    // Event emitted when beneficiaries are added to a vesting plan
    event AddedBeneficiaries(Beneficiary[] beneficiaries, bytes32 indexed vestingIdx);

    // Event emitted when tokens are released
    event TokensReleased(bytes32 indexed vestingIdx, address indexed beneficiary, uint256 amount);

    // Event emitted when unallocated tokens are withdrawn
    event UnallocatedTokensWithdrawn(bytes32 indexed vestingIdx, address indexed owner, uint256 amount);

    constructor() {}

    /**
     * @dev Adds multiple vesting plans in bulk.
     * Transfers the total token amount for each vesting plan from the sender to the contract.
     *
     * @param vestingPlanParams Array of vesting plan parameters to be added.
     * @param _projectName Name of the project for which the vesting plans are being added.
     * @param _tokenAddress Address of the ERC20 token to be vested.
     */
    function addVestingPlansBulk(
        VestingPlanParams[] calldata vestingPlanParams,
        string calldata _projectName,
        address _tokenAddress
    )
    external
    payable
    {
        bool hasCreationToken = IForcefiPackage(forcefiPackageAddress).hasCreationToken(msg.sender, _projectName);
        require(msg.value == feeAmount || hasCreationToken, "Invalid fee value or no creation token available");

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
    function addVestingPlan(
        VestingPlanParams memory params,
        string calldata _projectName,
        address _tokenAddress
    )
    internal
    {
        ERC20(_tokenAddress).safeTransferFrom(msg.sender, address(this), params.totalTokenAmount);

        uint vestingIdx = _tokenIdCounter;
        _tokenIdCounter += 1;

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

        addVestingBeneficiaries(UUID, params.beneficiaries);
        projectVestings[_projectName].push(UUID);
    }

    /**
     * @dev Adds beneficiaries to a vesting plan.
     * Can only be called by the owner of the vesting plan.
     *
     * @param _vestingIdx The ID of the vesting plan.
     * @param _beneficiaries Array of beneficiaries to be added.
     */
    function addVestingBeneficiaries(
        bytes32 _vestingIdx,
        Beneficiary[] memory _beneficiaries
    )
    public
    {
        require(vestingPlans[_vestingIdx].initialized, "Invalid vesting plan");
        require(vestingPlans[_vestingIdx].vestingOwner == msg.sender, "Only vesting owner can add beneficiaries");

        for (uint i = 0; i < _beneficiaries.length; i++) {
            require(
                vestingPlans[_vestingIdx].tokenAllocated + _beneficiaries[i].tokenAmount <= vestingPlans[_vestingIdx].totalTokenAmount,
                "Token allocation reached maximum for vesting plan"
            );
            require(_beneficiaries[i].beneficiaryAddress != address(0), "Invalid beneficiary address");

            IndividualVesting storage individualVesting = individualVestings[_vestingIdx][_beneficiaries[i].beneficiaryAddress];
            individualVesting.initialized = true;
            individualVesting.tokenAmount += _beneficiaries[i].tokenAmount;
            vestingPlans[_vestingIdx].tokenAllocated += _beneficiaries[i].tokenAmount;
        }

        emit AddedBeneficiaries(_beneficiaries, _vestingIdx);
    }

    /**
     * @dev Withdraws unallocated tokens from a vesting plan.
     * Can only be called by the owner of the vesting plan.
     *
     * @param _vestingIdx The ID of the vesting plan.
     */
    function withdrawUnallocatedTokens(bytes32 _vestingIdx) public nonReentrant {
        require(vestingPlans[_vestingIdx].initialized, "Invalid vesting plan");
        require(vestingPlans[_vestingIdx].vestingOwner == msg.sender, "Only vesting owner can withdraw tokens");

        uint256 unallocatedTokens = vestingPlans[_vestingIdx].totalTokenAmount - vestingPlans[_vestingIdx].tokenAllocated;
        require(unallocatedTokens > 0, "No unallocated tokens to withdraw");

        ERC20(vestingPlans[_vestingIdx].tokenAddress).safeTransfer(msg.sender, unallocatedTokens);
        vestingPlans[_vestingIdx].totalTokenAmount = vestingPlans[_vestingIdx].tokenAllocated;

        emit UnallocatedTokensWithdrawn(_vestingIdx, msg.sender, unallocatedTokens);
    }

    /**
     * @dev Releases vested tokens for the caller's individual vesting plan.
     * Transfers the releasable tokens to the caller.
     *
     * @param _vestingIdx The ID of the vesting plan.
     */
    function releaseVestedTokens(bytes32 _vestingIdx) public nonReentrant {
        uint256 vestedAmount = calculateVestedTokens(_vestingIdx);
        require(vestedAmount > 0, "TokenVesting: cannot release tokens, no vested tokens");

        IndividualVesting storage individualVesting = individualVestings[_vestingIdx][msg.sender];
        individualVesting.tokensReleased += vestedAmount;

        ERC20(vestingPlans[_vestingIdx].tokenAddress).safeTransfer(msg.sender, vestedAmount);

        emit TokensReleased(_vestingIdx, msg.sender, vestedAmount);
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
     * @param _projectName The name of the project.
     * @return bytes32[] Array of vesting plan IDs.
     */
    function getVestingsByProjectName(string memory _projectName) public view returns (bytes32[] memory) {
        return projectVestings[_projectName];
    }
}
