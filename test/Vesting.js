const { expect } = require("chai");

describe("Vesting", function () {
    let erc20Token, vestingContract, owner, addr1, addr2, mockedLzAddress;
    const name = "Test token";
    const symbol = "TST";
    const _projectName = "Forcefi";

    const vesting_1_label = "My Vesting Plan";
    const vesting_2_label = "My Vesting Plan2";

    const beneficiar_1 = ethers.Wallet.createRandom();
    const beneficiar_2 = ethers.Wallet.createRandom();

    const erc20Supply = "50000";

    let forcefiPackage;

    const vestingPlans = [
        {
            beneficiaries: [{ beneficiaryAddress: beneficiar_1, tokenAmount: 250 }],
            vestingPlanLabel: vesting_1_label,
            saleStart: Math.floor(Date.now() / 1000), // Current timestamp
            cliffPeriod: 60 * 60 * 24 * 30, // 30 days
            vestingPeriod: 60 * 60 * 24 * 365, // 1 year
            releasePeriod: 60 * 60 * 24 * 30, // Monthly releases
            tgePercent: 10, // 10% tokens at TGE
            totalTokenAmount: "1000"
        },
        {
            beneficiaries: [{ beneficiaryAddress: beneficiar_1, tokenAmount: 25 }],
            vestingPlanLabel: vesting_2_label,
            saleStart: Math.floor(Date.now() / 1000), // Current timestamp
            cliffPeriod: 60 * 60 * 24 * 30, // 30 days
            vestingPeriod: 60 * 60 * 24 * 365, // 1 year
            releasePeriod: 60 * 60 * 24 * 30, // Monthly releases
            tgePercent: 10, // 10%
            totalTokenAmount: "350"
        }
    ];

    // Helper function to deploy contracts
    const deployContracts = async () => {
        vestingContract = await ethers.deployContract("Vesting");
        [owner, addr1, addr2, mockedLzAddress] = await ethers.getSigners();
        erc20Token = await ethers.deployContract("ERC20Token", [name, symbol, erc20Supply, owner.address]);

        forcefiPackage = await ethers.deployContract("ForcefiPackage", [mockedLzAddress]);
        await vestingContract.setForcefiPackageAddress(forcefiPackage.getAddress());

        const MockOracle = await ethers.getContractFactory("MockV3Aggregator");
        const mockOracle = await MockOracle.deploy(
            "18", // decimals
            "1000"// initialAnswer
        );

        await forcefiPackage.whitelistTokenForInvestment(erc20Token.getAddress(), mockOracle.getAddress());

    };

    // Helper function to approve and add vesting plans
    const approveAndAddVestings = async (vestingPlansToUse) => {
        await erc20Token.approve(vestingContract.getAddress(), erc20Supply);
        await vestingContract.addVestingPlansBulk(vestingPlansToUse, _projectName, erc20Token.getAddress());
    };

    // Helper function to get vesting plan IDs
    const getProjectVestings = async () => {
        const projectVestings = await vestingContract.getVestingsByProjectName(_projectName);
        return projectVestings.toString().split(",");
    };

    beforeEach(async function () {
        await deployContracts();
    });

    describe("add vestings", function () {
        it("adding vesting plan", async function () {
            await approveAndAddVestings(vestingPlans);
            const [vesting1] = await getProjectVestings();
            const vestingPlan = await vestingContract.vestingPlans(vesting1);

            // Compare vesting data
            expect(vestingPlan[0]).to.equal(await erc20Token.getAddress());
            expect(vestingPlan[1]).to.equal(_projectName);
            expect(vestingPlan[2]).to.equal(vestingPlans[0].vestingPlanLabel);
            expect(vestingPlan[3]).to.equal(await owner.getAddress());
            expect(vestingPlan[4]).to.equal(vestingPlans[0].saleStart);
            expect(vestingPlan[5]).to.equal(vestingPlans[0].cliffPeriod);
            expect(vestingPlan[6]).to.equal(vestingPlans[0].vestingPeriod);
            expect(vestingPlan[7]).to.equal(vestingPlans[0].releasePeriod);
            expect(vestingPlan[8]).to.equal(vestingPlans[0].tgePercent);
            expect(vestingPlan[9]).to.equal(vestingPlans[0].totalTokenAmount);
            expect(vestingPlan[10]).to.equal(vestingPlans[0].beneficiaries[0].tokenAmount);

            // Compare token amounts
            const totalAllocatedTokens = Number(vestingPlans[0].totalTokenAmount) + Number(vestingPlans[1].totalTokenAmount);
            expect(await erc20Token.balanceOf(owner.address)).to.equal(erc20Supply - totalAllocatedTokens);
            expect(await erc20Token.balanceOf(vestingContract.getAddress())).to.equal(totalAllocatedTokens);

            // Verify beneficiary's vesting
            const beneficiar1 = await vestingContract.individualVestings(vesting1, beneficiar_1);
            expect(beneficiar1[0]).to.equal(vestingPlans[0].beneficiaries[0].tokenAmount);
            expect(beneficiar1[1]).to.equal(0);
        });

        it("adding vesting plan with project package", async function () {

            const feeAmount = 5;
            await vestingContract.setFeeAmount(feeAmount);

            await erc20Token.approve(vestingContract.getAddress(), erc20Supply);
            await expect(vestingContract.addVestingPlansBulk(vestingPlans, _projectName, erc20Token.getAddress())).to.be.revertedWith("Invalid fee value or no creation token available");

            const packageTotalPrice = 2000;
            const erc20TokenPrice = await forcefiPackage.getChainlinkDataFeedLatestAnswer(erc20Token.getAddress());
            const totalTokensPerPackage = packageTotalPrice * Number(erc20TokenPrice);
            await erc20Token.approve(forcefiPackage.getAddress(), totalTokensPerPackage.toString());
            await forcefiPackage.buyPackage(_projectName, "Accelerator", erc20Token.getAddress(), addr1.address);

            await approveAndAddVestings(vestingPlans);
            const [vesting1] = await getProjectVestings();
            const vestingPlan = await vestingContract.vestingPlans(vesting1);

            expect(vestingPlan[1]).to.equal(_projectName);
        });

        it("unlock unallocated tokens", async function () {
            await approveAndAddVestings(vestingPlans);
            const [vesting1] = await getProjectVestings();

            // Initial balances
            const totalAllocatedTokens = Number(vestingPlans[0].totalTokenAmount) + Number(vestingPlans[1].totalTokenAmount);
            expect(await erc20Token.balanceOf(owner.address)).to.equal(erc20Supply - totalAllocatedTokens);

            // Withdraw unallocated tokens
            const invalidVestingAddress = "0xa397bc7c0ff6ac261a7a658e96f6f457721577937cc4078360bcb683265671b2";
            await expect(vestingContract.withdrawUnallocatedTokens(invalidVestingAddress)).to.be.revertedWith("Invalid vesting plan");
            await expect(vestingContract.connect(addr1).withdrawUnallocatedTokens(vesting1)).to.be.revertedWith("Only vesting owner can withdraw tokens");

            await vestingContract.withdrawUnallocatedTokens(vesting1);
            expect(await erc20Token.balanceOf(owner.address)).to.equal(erc20Supply - vestingPlans[0].beneficiaries[0].tokenAmount - vestingPlans[1].totalTokenAmount);

            await expect(vestingContract.withdrawUnallocatedTokens(vesting1)).to.be.revertedWith("No unallocated tokens to withdraw");
        });

        // Add other test cases here using helper functions as needed
        it("adding additional beneficiaries", async function () {
            // Add vesting plan
            await approveAndAddVestings(vestingPlans);
            // Get vesting by project name
            const [vesting1] = await getProjectVestings();

            const benificariesArray = [{
                beneficiaryAddress: beneficiar_2,
                tokenAmount: vestingPlans[0].totalTokenAmount - vestingPlans[0].beneficiaries[0].tokenAmount
            }]

            await vestingContract.addVestingBeneficiaries(vesting1, benificariesArray);

            await expect(vestingContract.connect(addr1).addVestingBeneficiaries(vesting1, benificariesArray)).to.be.revertedWith("Only vesting owner can add beneficiaries");

            const invalidVestingAddress = "0xa397bc7c0ff6ac261a7a658e96f6f457721577937cc4078360bcb683265671b2";
            await expect(vestingContract.addVestingBeneficiaries(invalidVestingAddress, benificariesArray)).to.be.revertedWith("Invalid vesting plan");

            // Try to add address(0) as benificiar
            const invalidBenificariesArray = [{
                beneficiaryAddress: '0x0000000000000000000000000000000000000000',
                tokenAmount: 0
            }]
            await expect(vestingContract.addVestingBeneficiaries(vesting1, invalidBenificariesArray)).to.be.revertedWith("Invalid beneficiary address");

            const vestingPlan = await vestingContract.vestingPlans(vesting1);
            expect(vestingPlan[10]).to.equal(vestingPlans[0].beneficiaries[0].tokenAmount + benificariesArray[0].tokenAmount);

            // Try to add vesting beneficiaries one more time
            await expect(vestingContract.addVestingBeneficiaries(vesting1, benificariesArray)).to.be.revertedWith("Token allocation reached maximum for vesting plan");
        });

        it("release vested tokens", async function () {
            const getCurrentTime = async () => {
                const currentBlock = await ethers.provider.getBlock("latest");
                return currentBlock.timestamp;
            }

            const cliffPeriodTime = 1000;
            const vestingPeriodTime = 5000;
            const releasePeriodTime = 1000;
            const benificiarTokenAmount = 2500;

            // Ensure the saleStart is properly awaited
            const releasableVestingPlan = [
                {
                    beneficiaries: [
                        {
                            beneficiaryAddress: addr1.address, // Use the address here
                            tokenAmount: benificiarTokenAmount
                        }
                    ],
                    vestingPlanLabel: vesting_1_label,
                    saleStart: await getCurrentTime(),  // Await the current time
                    cliffPeriod: cliffPeriodTime,
                    vestingPeriod: vestingPeriodTime,
                    releasePeriod: releasePeriodTime,
                    tgePercent: 10,
                    totalTokenAmount: "10000"
                }
            ];

            // Add vesting plan
            await erc20Token.approve(vestingContract.getAddress(), erc20Supply);
            await vestingContract.addVestingPlansBulk(releasableVestingPlan, _projectName, erc20Token.getAddress());

            // Get vesting by project name
            const projectVestings = await vestingContract.getVestingsByProjectName(_projectName);
            const vestingId = projectVestings[0]; // Extract the first vesting plan ID

            // Initially, no vested tokens should be claimable
            await expect(vestingContract.releaseVestedTokens(vestingId)).to.be.revertedWith("TokenVesting: cannot release tokens, no vested tokens");

            expect(await erc20Token.balanceOf(addr1.address)).to.equal(0);

            // Release TGE tokens
            await vestingContract.connect(addr1).releaseVestedTokens(vestingId);

            const tgeTokenCount = benificiarTokenAmount * releasableVestingPlan[0].tgePercent / 100;
            expect(await erc20Token.balanceOf(addr1.address)).to.equal(tgeTokenCount);

            await expect(vestingContract.connect(addr1).releaseVestedTokens(vestingId)).to.be.revertedWith("TokenVesting: cannot release tokens, no vested tokens");

            // Fast forward time to pass the cliff period
            await ethers.provider.send('evm_increaseTime', [cliffPeriodTime]);
            await ethers.provider.send('evm_mine');
            await expect(vestingContract.connect(addr1).releaseVestedTokens(vestingId)).to.be.revertedWith("TokenVesting: cannot release tokens, no vested tokens");

            // Fast forward time to pass one release period
            await ethers.provider.send('evm_increaseTime', [releasePeriodTime]);
            await ethers.provider.send('evm_mine');

            await vestingContract.connect(addr1).releaseVestedTokens(vestingId);

            // Should release tokens proportional to the release period
            const oneReleasePeriodTokenCount = (benificiarTokenAmount - tgeTokenCount) / (vestingPeriodTime / releasePeriodTime);
            expect(await erc20Token.balanceOf(addr1.address)).to.equal(tgeTokenCount + oneReleasePeriodTokenCount);

            // Fast forward time to pass the entire vesting period
            await ethers.provider.send('evm_increaseTime', [vestingPeriodTime]);
            await ethers.provider.send('evm_mine');

            // Releasing all remaining tokens
            await vestingContract.connect(addr1).releaseVestedTokens(vestingId);
            expect(await erc20Token.balanceOf(addr1.address)).to.equal(benificiarTokenAmount);

            // No further tokens should be available for release
            await expect(vestingContract.connect(addr1).releaseVestedTokens(vestingId)).to.be.revertedWith("TokenVesting: cannot release tokens, no vested tokens");
        });

        it("release vested tokens for paused contract", async function () {
            const releasableVestingPlan = [
                {
                    beneficiaries: [
                        {
                            beneficiaryAddress: addr1.address,
                            tokenAmount: 2500
                        },
                        {
                            beneficiaryAddress: addr2.address,
                            tokenAmount: 2500
                        }
                    ],
                    vestingPlanLabel: vesting_1_label,
                    saleStart: Math.floor(Date.now() / 1000),
                    cliffPeriod: 60 * 60 * 24 * 30,  // 30 days
                    vestingPeriod: 60 * 60 * 24 * 365,  // 1 year
                    releasePeriod: 60 * 60 * 24 * 30,  // Monthly releases
                    tgePercent: 10,
                    totalTokenAmount: "10000"
                }
            ];

            // Deploy and initialize the pausable ERC20 token
            const erc20PausableToken = await ethers.deployContract("ERC20PausableBurnableToken", [name, symbol, erc20Supply, owner.address]);

            // Add vesting plan
            await erc20PausableToken.approve(vestingContract.getAddress(), erc20Supply);
            await vestingContract.addVestingPlansBulk(releasableVestingPlan, _projectName, erc20PausableToken.getAddress());

            // Get vesting by project name
            const projectVestings = await vestingContract.getVestingsByProjectName(_projectName);
            const vestingId = projectVestings[0]; // Get the vesting plan ID

            // Check initial balance
            expect(await erc20PausableToken.balanceOf(addr1.address)).to.equal(0);

            // Release TGE tokens for addr1
            await vestingContract.connect(addr1).releaseVestedTokens(vestingId);
            const tgeTokenCountAddr1 = releasableVestingPlan[0].beneficiaries[0].tokenAmount * releasableVestingPlan[0].tgePercent / 100;
            expect(await erc20PausableToken.balanceOf(addr1.address)).to.equal(tgeTokenCountAddr1);

            // Ensure no additional tokens can be claimed yet
            await expect(vestingContract.connect(addr1).releaseVestedTokens(vestingId)).to.be.revertedWith("TokenVesting: cannot release tokens, no vested tokens");

            // Pause ERC20 contract
            await erc20PausableToken.pause();

            // Ensure addr2 cannot release tokens while the contract is paused
            await expect(vestingContract.connect(addr2).releaseVestedTokens(vestingId)).to.be.revertedWith("Pausable: paused and not whitelisted");

            // Whitelist vesting contract for transfers during paused state
            await erc20PausableToken.addWhitelistedContract(vestingContract.getAddress());

            // addr2 should now be able to release TGE tokens
            await vestingContract.connect(addr2).releaseVestedTokens(vestingId);
            const tgeTokenCountAddr2 = releasableVestingPlan[0].beneficiaries[1].tokenAmount * releasableVestingPlan[0].tgePercent / 100;
            expect(await erc20PausableToken.balanceOf(addr2.address)).to.equal(tgeTokenCountAddr2);
        });
    });
});
