//// SPDX-License-Identifier: MIT
//pragma solidity ^0.8.0;
//
//import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
//import "@openzeppelin/contracts/access/Ownable.sol";
//import "./../VestingLibrary.sol"; // Importing VestingLibrary for calculating releasable amounts
//
//contract PeriodStaking is Ownable {
//
//    using VestingLibrary for uint256;
//
//    IERC20 public token; // ERC20 token being locked
//    IERC20 public treasuryToken; // ERC20 tokens from Treasury
//    bool public treasuryTokenLocked;
//
//    struct Lock {
//        uint256 amount;       // Amount of tokens locked
//        uint256 lockedAt;     // Timestamp when tokens were locked
//    }
//
//    mapping(address => Lock[]) public userLocks; // Stores user token locks
//    mapping(address => uint256) public userReleased; // Tracks total tokens released for each user
//
//    uint256 public treasuryBalance; // Total tokens in the Treasury
//    uint256 public lastReleaseTime; // Last time tokens were released from the treasury
//    uint256 public totalLocked; // Total amount of tokens locked by all users
//
//    uint256 public lockUpPeriod = 6000; // Lock-up period before tokens can be claimed (1 month)
//
//    // Vesting parameters
//    uint256 public vestingStartTime;
//    uint256 public vestingDuration; // 1-year vesting duration
//    uint256 public vestingPeriod; // Monthly vesting periods
//    uint256 public tgeAmount;
//
//    struct FeeMultiplier {
//        uint256 beginnerFeeThreshold;  // Staking time for beginner multiplier
//        uint256 beginnerMultiplier;    // Multiplier for beginner staking period
//        uint256 intermediateFeeThreshold; // Staking time for intermediate multiplier
//        uint256 intermediateMultiplier; // Multiplier for intermediate staking period
//        uint256 maximumFeeThreshold;   // Staking time for maximum multiplier
//        uint256 maximumMultiplier;     // Multiplier for maximum staking period
//    }
//
//    FeeMultiplier public feeMultiplier;
//
//    constructor(
//        IERC20 _token,
//        IERC20 _treasuryToken,
//        uint256 _initialTreasuryBalance,
//        uint256 _vestingStartTime, // Vesting starts at this time
//        uint256 _vestingDuration, // Vesting starts at this time
//        uint256 _vestingPeriod, // Vesting starts at this time
//        uint256 _tgeAmount // Vesting starts at this time
//
//    ) Ownable(msg.sender) {
//        token = _token;
//        treasuryToken = _treasuryToken;
////        treasuryBalance = _initialTreasuryBalance;
//        vestingStartTime = _vestingStartTime;
//        vestingDuration = _vestingDuration;
//        vestingPeriod = _vestingPeriod;
//        tgeAmount = _tgeAmount;
//        lastReleaseTime = block.timestamp;
//
//    }
//
//    event Locked(address indexed user, uint256 amount);
//    event Claimed(address indexed user, uint256 amount);
//
//    /**
//     * @dev Lock tokens for the sender.
//     * @param amount The amount of tokens to lock.
//     */
//    function lockTokens(uint256 amount) external {
//        require(amount > 0, "Amount must be greater than 0");
//
//        // Transfer tokens from user to contract
//        token.transferFrom(msg.sender, address(this), amount);
//
//        // Store lock details
//        userLocks[msg.sender].push(Lock({
//        amount: amount,
//        lockedAt: block.timestamp
//        }));
//
//        totalLocked += amount;
//
//        emit Locked(msg.sender, amount);
//    }
//
//    /**
//     * @dev Claim the tokens based on the user's locked amount and monthly releases.
//     */
//    function claim() external {
////        updateTreasuryRelease(); // Releases all due tokens based on months passed
//
//        uint256 totalClaimable = 0;
//        uint256 totalEligibleLocked = getEligibleLockedTokens(); // Total eligible locked tokens across users
//
//        // Get the total amount releasable for the entire project for this month
//        uint256 projectReleasableAmount = getProjectReleasableAmount();
//
//        // Loop through all user locks and calculate claimable amounts
//        for (uint256 i = 0; i < userLocks[msg.sender].length; i++) {
//            Lock storage lock = userLocks[msg.sender][i];
//
//            // Only allow claim if the lock is past the lock-up period
//            if (block.timestamp >= lock.lockedAt + lockUpPeriod) {
//                // Calculate the user's proportion of the total project releasable amount
//                uint256 userProportion = (lock.amount * 1e18) / totalEligibleLocked;
//                uint256 userClaimAmount = (userProportion * projectReleasableAmount) / 1e18;
//
//                // Apply the staking time multiplier
//                uint256 stakingTime = block.timestamp - lock.lockedAt;
//                uint256 multiplier = getMultiplier(stakingTime);
////                userClaimAmount = (userClaimAmount * multiplier) / 100;
//
//                // Add the user's claim amount for this lock
//                totalClaimable += userClaimAmount;
//            }
//        }
//
////        return totalClaimable;
//
//        require(totalClaimable > 0, "No tokens available to claim");
//        require(treasuryBalance >= totalClaimable, "Not enough tokens in the treasury");
//
//        // Transfer the accumulated claimable tokens to the user
//        treasuryToken.transfer(msg.sender, totalClaimable);
//        userReleased[msg.sender] += totalClaimable; // Update the released amount
//
//        emit Claimed(msg.sender, totalClaimable);
//    }
//
//    /**
//     * @dev Calculates the total releasable amount for the entire project for the current month.
//     * This uses the VestingLibrary to compute the amount of tokens that can be released based on vesting parameters.
//     */
//    function getProjectReleasableAmount() public view returns (uint256) {
//        uint256 releasableAmount = VestingLibrary.computeReleasableAmount(
//            vestingStartTime,
//            vestingDuration,
//            vestingPeriod,
//            lockUpPeriod,
//            tgeAmount,
//            treasuryBalance,
//            0 // No amount has been released for the entire project at this point
//        );
//        return releasableAmount;
//    }
//
//    /**
//     * @dev Releases tokens from the treasury if the release period has passed (monthly release).
//     */
//    function updateTreasuryRelease() internal {
//        uint256 currentTime = block.timestamp;
//        uint256 monthsPassed = (currentTime - lastReleaseTime) / vestingPeriod;
//
//        // Release tokens for all months that have passed since the last release
//        if (monthsPassed > 0) {
//            uint256 totalRelease = monthsPassed * getProjectReleasableAmount();
//
//            require(treasuryBalance >= totalRelease, "Not enough tokens in treasury for release");
//
//            treasuryBalance -= totalRelease;
//            lastReleaseTime += monthsPassed * vestingPeriod; // Move forward the release time by the number of months passed
//        }
//    }
//
///**
// * @dev Unstake the current stake and get the locked tokens back.
// */
//    function unstake() external {
//        uint256 totalUnstakable = 0;
//
//        // Loop through all user locks and calculate unstakable amounts
//        for (uint256 i = 0; i < userLocks[msg.sender].length; i++) {
//            Lock storage lock = userLocks[msg.sender][i];
//
//            // Calculate the total unstakable amount
//            totalUnstakable += lock.amount;
//        }
//
//        require(totalUnstakable > 0, "No tokens available to unstake");
//
//        // Transfer the unstakable tokens back to the user
//        token.transfer(msg.sender, totalUnstakable);
//
//        // Reset the user's locks
//        delete userLocks[msg.sender];
//
//        // Update the total locked amount
//        totalLocked -= totalUnstakable;
//
//        emit Claimed(msg.sender, totalUnstakable);
//    }
//    /**
//     * @dev Returns the total amount of locked tokens that are eligible for claiming (i.e., past lock-up period).
//     */
//    function getEligibleLockedTokens() public view returns (uint256) {
//        uint256 eligibleLocked = 0;
//
//        // Loop through all users' locks and sum the eligible tokens
//        for (uint256 i = 0; i < userLocks[msg.sender].length; i++) {
//            Lock storage lock = userLocks[msg.sender][i];
//
//            if (block.timestamp >= lock.lockedAt + lockUpPeriod) {
//                eligibleLocked += lock.amount;
//            }
//        }
//
//        return eligibleLocked;
//    }
//
//    /**
//     * @dev Deposit tokens into the treasury for future claims.
//     */
//    function depositTreasuryTokens(uint256 amount) external onlyOwner {
//        require(!treasuryTokenLocked, "Treasury token already locked");
//        treasuryToken.transferFrom(msg.sender, address(this), amount);
//        treasuryBalance += amount;
//        treasuryTokenLocked = true;
//    }
//
//    /**
//     * @dev Set the lock-up period before users can claim their tokens (default is 30 days).
//     */
//    function setLockUpPeriod(uint256 period) external onlyOwner {
//        lockUpPeriod = period;
//    }
//
//    /**
//     * @dev Returns the multiplier based on the staking time.
//     */
//    function getMultiplier(uint256 stakingTime) internal view returns (uint256) {
//        if (stakingTime >= feeMultiplier.maximumFeeThreshold) {
//            return 100 + feeMultiplier.maximumMultiplier;
//        } else if (stakingTime >= feeMultiplier.intermediateFeeThreshold) {
//            return 100 + feeMultiplier.intermediateMultiplier;
//        } else if (stakingTime >= feeMultiplier.beginnerFeeThreshold) {
//            return 100 + feeMultiplier.beginnerMultiplier;
//        } else {
//            return 100; // No multiplier, base 100%
//        }
//    }
//
//    /**
//     * @dev Set the fee multiplier structure.
//     */
//    function setFeeMultiplier(
//        uint256 _beginnerFeeThreshold,
//        uint256 _beginnerMultiplier,
//        uint256 _intermediateFeeThreshold,
//        uint256 _intermediateMultiplier,
//        uint256 _maximumFeeThreshold,
//        uint256 _maximumMultiplier
//    ) external onlyOwner {
//        feeMultiplier.beginnerFeeThreshold = _beginnerFeeThreshold;
//        feeMultiplier.beginnerMultiplier = _beginnerMultiplier;
//        feeMultiplier.intermediateFeeThreshold = _intermediateFeeThreshold;
//        feeMultiplier.intermediateMultiplier = _intermediateMultiplier;
//        feeMultiplier.maximumFeeThreshold = _maximumFeeThreshold;
//        feeMultiplier.maximumMultiplier = _maximumMultiplier;
//    }
//}
//
//// Construct contract - set multipliers, minimal lock time and distribution token address
//
//// Lock tokens as owner of contract
//// Distribute tokens by periods proportionally
//// Set first period of distribution + amount of periods
//
//// Lock investor tokens
//// set lock as future interest gainer
//
//// Get staking interest
//// calculate staking interest by periods starting from first
//// transfer staking interest - set eligible tokens to 0
//
//// Stop staking
//// remove from future interest gainer list
//// transfer staking interest + initial stake
