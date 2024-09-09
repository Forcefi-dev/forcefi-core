const { expect } = require("chai");

describe("ERC20Token", function () {

    let erc20Token;
    let owner, addr1, addr2, mockedLzAddress;
    const name = "Test token";
    const symbol = "TST";
    const initialSupply = 20000;
    const initialSupply2 = 50000;
    const _projectName = "Forcefi";

    const vesting_1_label = "My Vesting Plan"
    const vesting_2_label = "My Vesting Plan2"

    const beneficiar_1 = "0x233d98f5590471DBD3ef106beff290971A813092";
    const beneficiar_2 = "0xf6f895b17744c4F30C146Db30Cd3c25C8bbF5837";
    const vestingPlans = [
        {
            benificiars: [
                {
                    beneficiarAddress: beneficiar_1,
                    tokenAmount: 250
                }
            ],
            vestingPlanLabel: vesting_1_label,
            saleStart: Math.floor(Date.now() / 1000), // Example timestamp
            cliffPeriod: 60 * 60 * 24 * 30, // Example: 30 days
            vestingPeriod: 60 * 60 * 24 * 365, // Example: 1 year
            releasePeriod: 60 * 60 * 24 * 30, // Example: monthly releases
            tgePercent: 10, // 10%
            totalTokenAmount: "1000" // 1000 tokens
        },
        {
            benificiars: [
                {
                    beneficiarAddress: beneficiar_1,
                    tokenAmount: 25
                }
            ],
            vestingPlanLabel: vesting_2_label,
            saleStart: Math.floor(Date.now() / 1000), // Example timestamp
            cliffPeriod: 60 * 60 * 24 * 30, // Example: 30 days
            vestingPeriod: 60 * 60 * 24 * 365, // Example: 1 year
            releasePeriod: 60 * 60 * 24 * 30, // Example: monthly releases
            tgePercent: 10, // 10%
            totalTokenAmount: "350" // 1000 tokens
        }
    ];
    const erc20Supply = "50000";
    let vestingContract;

    beforeEach(async function () {
        vestingContract = await ethers.deployContract("VestingFinal");
        [owner, addr1, addr2, mockedLzAddress] = await ethers.getSigners();
        erc20Token = await ethers.deployContract("ERC20Token", [name, symbol, erc20Supply]);

        const forcefiPackage = await ethers.deployContract("ForcefiPackage", [mockedLzAddress]);
        await vestingContract.setForcefiPackageAddress(forcefiPackage.getAddress());
    });

    describe("add vestings", function () {

        it("adding vesting plan", async function () {

            // Add vesting plan
            await erc20Token.approve(vestingContract.getAddress(), erc20Supply)
            await vestingContract.addVestingPlansBulk(vestingPlans, _projectName, erc20Token.getAddress());

            // Get vesting by project name
            const projectVestings = await vestingContract.getVestingsForProject(_projectName);
            const [vesting1, vesting2] = projectVestings.toString().split(',');
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
            expect(vestingPlan[10]).to.equal(vestingPlans[0].benificiars[0].tokenAmount);

            // Compare token amount in vesting contract / owner
            expect(await erc20Token.balanceOf(owner.address)).to.equal(erc20Supply - vestingPlans[0].totalTokenAmount - vestingPlans[1].totalTokenAmount);
            expect(await erc20Token.balanceOf(vestingContract.getAddress())).to.equal(Number(vestingPlans[0].totalTokenAmount) + Number(vestingPlans[1].totalTokenAmount));

            // Compare benificaries vestings
            const beneficiar1 = await vestingContract.individualVestings(vesting1, beneficiar_1)
            expect(beneficiar1[0]).to.equal(vestingPlans[0].benificiars[0].tokenAmount);
            expect(beneficiar1[1]).to.equal(0);
        });

        it("unlock unallocated tokens", async function () {
            // Add vesting plan
            await erc20Token.approve(vestingContract.getAddress(), erc20Supply)
            await vestingContract.addVestingPlansBulk(vestingPlans, _projectName, erc20Token.getAddress());
            // Get vesting by project name
            const projectVestings = await vestingContract.getVestingsForProject(_projectName);
            const [vesting1, vesting2] = projectVestings.toString().split(',');

            expect(await erc20Token.balanceOf(owner.address)).to.equal(erc20Supply - vestingPlans[0].totalTokenAmount - vestingPlans[1].totalTokenAmount);
            await vestingContract.withdrawUnallocatedTokens(vesting1);

            expect(await erc20Token.balanceOf(owner.address)).to.equal(erc20Supply - vestingPlans[0].benificiars[0].tokenAmount - vestingPlans[1].totalTokenAmount);
            expect(await erc20Token.balanceOf(vestingContract.getAddress())).to.equal(Number(vestingPlans[0].benificiars[0].tokenAmount) + Number(vestingPlans[1].totalTokenAmount));
        });

        it("adding additional beneficiaries", async function () {
            // Add vesting plan
            await erc20Token.approve(vestingContract.getAddress(), erc20Supply)
            await vestingContract.addVestingPlansBulk(vestingPlans, _projectName, erc20Token.getAddress());
            // Get vesting by project name
            const projectVestings = await vestingContract.getVestingsForProject(_projectName);
            const [vesting1, vesting2] = projectVestings.toString().split(',');

            const benificariesArray = [{
                beneficiarAddress: beneficiar_2,
                tokenAmount: vestingPlans[0].totalTokenAmount - vestingPlans[0].benificiars[0].tokenAmount
            }]

            await vestingContract.addVestingBeneficiar(vesting1, benificariesArray);

            const vestingPlan = await vestingContract.vestingPlans(vesting1);
            expect(vestingPlan[10]).to.equal(vestingPlans[0].benificiars[0].tokenAmount + benificariesArray[0].tokenAmount);

            // Try to add vesting beneficiaries one more time
            await expect(vestingContract.addVestingBeneficiar(vesting1, benificariesArray)).to.be.revertedWith("Token allocation reached maximum for vesting plan");
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
            const releasableVestingPlan = [
                {
                    benificiars: [
                        {
                            beneficiarAddress: addr1,
                            tokenAmount: benificiarTokenAmount
                        }
                    ],
                    vestingPlanLabel: vesting_1_label,
                    saleStart: getCurrentTime(),
                    cliffPeriod: cliffPeriodTime,
                    vestingPeriod: vestingPeriodTime,
                    releasePeriod: releasePeriodTime,
                    tgePercent: 10,
                    totalTokenAmount: "10000"
                }]

            // Add vesting plan
            await erc20Token.approve(vestingContract.getAddress(), erc20Supply)
            await vestingContract.addVestingPlansBulk(releasableVestingPlan, _projectName, erc20Token.getAddress());

            // Get vesting by project name
            const projectVestings = await vestingContract.getVestingsForProject(_projectName);

            await expect(vestingContract.releaseVestedTokens(projectVestings.toString())).to.be.revertedWith("TokenVesting: cannot release tokens, no vested tokens");

            expect(await erc20Token.balanceOf(addr1.address)).to.equal(0);

            await vestingContract.connect(addr1).releaseVestedTokens(projectVestings.toString())

            // Release TGE tokens
            const tgeTokenCount = releasableVestingPlan[0].benificiars[0].tokenAmount * releasableVestingPlan[0].tgePercent / 100;
            expect(await erc20Token.balanceOf(addr1.address)).to.equal(tgeTokenCount);

            await expect(vestingContract.connect(addr1).releaseVestedTokens(projectVestings.toString())).to.be.revertedWith("TokenVesting: cannot release tokens, no vested tokens");

            // Pass cliffperiod time
            await ethers.provider.send('evm_increaseTime', [cliffPeriodTime]);
            await ethers.provider.send('evm_mine');
            await expect(vestingContract.connect(addr1).releaseVestedTokens(projectVestings.toString())).to.be.revertedWith("TokenVesting: cannot release tokens, no vested tokens");

            // Pass one releasePeriod time
            await ethers.provider.send('evm_increaseTime', [releasePeriodTime]);
            await ethers.provider.send('evm_mine');

            await vestingContract.connect(addr1).releaseVestedTokens(projectVestings.toString())

            // Should release vestingPeriod / releasePeriod tokens
            const oneReleasePeriodTokenCount = (benificiarTokenAmount - tgeTokenCount) / (vestingPeriodTime / releasePeriodTime)
            expect(await erc20Token.balanceOf(addr1.address)).to.equal(tgeTokenCount + oneReleasePeriodTokenCount);


            // Pass whole vestingPeriod
            await ethers.provider.send('evm_increaseTime', [vestingPeriodTime]);
            await ethers.provider.send('evm_mine');

            // Claim tokens should release whole amount
            await vestingContract.connect(addr1).releaseVestedTokens(projectVestings.toString())
            expect(await erc20Token.balanceOf(addr1.address)).to.equal(benificiarTokenAmount);

            // By claiming again should revert
            await expect(vestingContract.connect(addr1).releaseVestedTokens(projectVestings.toString())).to.be.revertedWith("TokenVesting: cannot release tokens, no vested tokens");
        });

        it("release vested tokens for paused contract", async function () {
            const releasableVestingPlan = [
                {
                    benificiars: [
                        {
                            beneficiarAddress: addr1,
                            tokenAmount: 2500
                        },
                        {
                            beneficiarAddress: addr2,
                            tokenAmount: 2500
                        }
                    ],
                    vestingPlanLabel: vesting_1_label,
                    saleStart: Math.floor(Date.now() / 1000), // Example timestamp
                    cliffPeriod: 60 * 60 * 24 * 30, // Example: 30 days
                    vestingPeriod: 60 * 60 * 24 * 365, // Example: 1 year
                    releasePeriod: 60 * 60 * 24 * 30, // Example: monthly releases
                    tgePercent: 10, // 10%
                    totalTokenAmount: "10000" // 1000 tokens
                }]
            const erc20PausableToken = await ethers.deployContract("ERC20PausableBurnableToken", [name, symbol, erc20Supply]);

            // Add vesting plan
            await erc20PausableToken.approve(vestingContract.getAddress(), erc20Supply)
            await vestingContract.addVestingPlansBulk(releasableVestingPlan, _projectName, erc20PausableToken.getAddress());

            // Get vesting by project name
            const projectVestings = await vestingContract.getVestingsForProject(_projectName);
            const [vesting1, vesting2] = projectVestings.toString().split(',');

            expect(await erc20PausableToken.balanceOf(addr1.address)).to.equal(0);

            // Release TGE tokens
            await vestingContract.connect(addr1).releaseVestedTokens(vesting1)
            expect(await erc20PausableToken.balanceOf(addr1.address)).to.equal(releasableVestingPlan[0].benificiars[0].tokenAmount * releasableVestingPlan[0].tgePercent / 100);

            await expect(vestingContract.connect(addr1).releaseVestedTokens(vesting1)).to.be.revertedWith("TokenVesting: cannot release tokens, no vested tokens");

            // Pause ERC20 token contract
            await erc20PausableToken.pause();
            await expect(vestingContract.connect(addr2).releaseVestedTokens(vesting1)).to.be.revertedWith("Pausable: paused and not whitelisted");

            await erc20PausableToken.addWhitelistedContract(vestingContract.getAddress());
            await vestingContract.connect(addr2).releaseVestedTokens(vesting1)
            expect(await erc20PausableToken.balanceOf(addr2.address)).to.equal(releasableVestingPlan[0].benificiars[0].tokenAmount * releasableVestingPlan[0].tgePercent / 100);
        });
    });
});
