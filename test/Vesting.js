const { expect } = require("chai");
const { ethers } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

describe("Vesting Contract Tests", function () {
  let Vesting;
  let vesting;
  let Token;
  let token;
  let owner;
  let addr1;
  let addr2;
  let addrs;

  beforeEach(async function () {
    [owner, addr1, addr2, ...addrs] = await ethers.getSigners();

    // Deploy mock ERC20 token
    Token = await ethers.getContractFactory("ERC20Token20Dec");
    token = await Token.deploy("Test Token", "TEST", ethers.parseEther("1000000"), owner.address);
    await token.waitForDeployment();

    // Deploy Vesting contract
    Vesting = await ethers.getContractFactory("Vesting");
    vesting = await Vesting.deploy();
    await vesting.waitForDeployment();
  });

  describe("VestingLibrary Tests", function () {
    let tester;
    let currentTime;
    
    beforeEach(async function () {
      const VestingLibraryTester = await ethers.getContractFactory("VestingLibraryTester");
      tester = await VestingLibraryTester.deploy();
      await tester.waitForDeployment();
      
      const latestBlock = await ethers.provider.getBlock('latest');
      currentTime = latestBlock.timestamp;
    });

    describe("generateUUID", function () {
      it("should generate unique UUIDs for different inputs", async function () {
        const id1 = 1;
        const id2 = 2;
        
        const uuid1 = await tester.generateUUID(id1);
        const uuid2 = await tester.generateUUID(id2);

        expect(uuid1).to.not.equal(uuid2);
      });
    });

    describe("computeReleasableAmount", function () {
      const duration = 365 * 24 * 60 * 60; // 1 year
      const period = 30 * 24 * 60 * 60; // 30 days
      const lockUpPeriod = 90 * 24 * 60 * 60; // 90 days
      const tgeAmount = 20; // 20%
      const invested = ethers.parseEther("1000"); // 1000 tokens
      const released = 0; 
      beforeEach(async function () {
        await ethers.provider.send("evm_mine");
      });

      it("should return correct amount after lock-up but before full vesting", async function () {        // Move time to just after lock-up period
        await ethers.provider.send("evm_increaseTime", [lockUpPeriod + period]);
        await ethers.provider.send("evm_mine");

        const expectedTGE = (invested * BigInt(tgeAmount)) / BigInt(100);
        const vestingAmount = invested - expectedTGE;
        const totalPeriods = BigInt(duration) / BigInt(period);
        const vestedPeriods = BigInt(1); // One period passed
        
        const expectedVested = (vestingAmount * vestedPeriods) / totalPeriods;
        const expectedTotal = expectedTGE + expectedVested;

        const amount = await tester.computeReleasableAmount(
          currentTime,
          duration,
          period,
          lockUpPeriod,
          tgeAmount,
          invested,
          released
        );

        expect(amount).to.equal(expectedTotal);
      });

      it("should return full amount after complete vesting period", async function () {        // Move time to after complete vesting period
        const newTime = currentTime + duration + lockUpPeriod + 1;
        await time.setNextBlockTimestamp(newTime);
        await ethers.provider.send("evm_mine");

        const amount = await tester.computeReleasableAmount(
          currentTime,
          duration,
          period,
          lockUpPeriod,
          tgeAmount,
          invested,
          released
        );

        expect(amount).to.equal(invested);
      });

      it("should handle partial releases correctly", async function () {
        const partialRelease = ethers.parseEther("200"); // 200 tokens released
        
        const amount = await tester.computeReleasableAmount(
          currentTime,
          duration,
          period,
          lockUpPeriod,
          tgeAmount,
          invested,
          partialRelease
        );

        const expectedTGE = (invested * BigInt(tgeAmount)) / BigInt(100);
        expect(amount).to.equal(expectedTGE - partialRelease);
      });
    });
  });

  describe("Vesting Contract Functionality", function () {
    let beneficiaries;
    let vestingPlanParams;
    const projectName = "TestProject";
    
    beforeEach(async function () {
      // Approve tokens for vesting
      await token.approve(await vesting.getAddress(), ethers.parseEther("10000"));

      beneficiaries = [
        {
          beneficiaryAddress: addr1.address,
          tokenAmount: ethers.parseEther("100")
        },
        {
          beneficiaryAddress: addr2.address,
          tokenAmount: ethers.parseEther("200")
        }
      ];

      vestingPlanParams = {
        beneficiaries: beneficiaries,
        vestingPlanLabel: "Test Plan",
        saleStart: Math.floor(Date.now() / 1000),
        cliffPeriod: 90 * 24 * 60 * 60, // 90 days
        vestingPeriod: 365 * 24 * 60 * 60, // 1 year
        releasePeriod: 30 * 24 * 60 * 60, // 30 days
        tgePercent: 20,
        totalTokenAmount: ethers.parseEther("300")
      };
    });

    describe("Adding Vesting Plans", function () {
      it("should add a vesting plan successfully", async function () {
        await vesting.addVestingPlansBulk(
          [vestingPlanParams],
          projectName,
          await token.getAddress()
        );

        const plans = await vesting.getVestingsByProjectName(projectName);
        expect(plans.length).to.equal(1);
      });

      it("should fail if total tokens exceed approved amount", async function () {
        vestingPlanParams.totalTokenAmount = ethers.parseEther("20000");
        await expect(
          vesting.addVestingPlansBulk(
            [vestingPlanParams],
            projectName,
            await token.getAddress()
          )
        ).to.be.reverted;
      });

      it("should add multiple vesting plans", async function () {
        const secondPlan = { ...vestingPlanParams };
        secondPlan.vestingPlanLabel = "Test Plan 2";
        
        await vesting.addVestingPlansBulk(
          [vestingPlanParams, secondPlan],
          projectName,
          await token.getAddress()
        );

        const plans = await vesting.getVestingsByProjectName(projectName);
        expect(plans.length).to.equal(2);
      });
    });

    describe("Token Release", function () {
      let vestingIdx;
      let startTime;

      beforeEach(async function () {
        // Get current block time and set start time for vesting
        const latestBlock = await ethers.provider.getBlock('latest');
        startTime = latestBlock.timestamp;
        vestingPlanParams.saleStart = startTime;
        
        await vesting.addVestingPlansBulk(
          [vestingPlanParams],
          projectName,
          await token.getAddress()
        );
        const plans = await vesting.getVestingsByProjectName(projectName);
        vestingIdx = plans[0];
      });

      it("should release TGE tokens immediately", async function () {
        const initialBalance = await token.balanceOf(addr1.address);
        await vesting.connect(addr1).releaseVestedTokens(vestingIdx);
        
        const totalAmount = ethers.parseEther("100");
        const expectedTGE = (totalAmount * BigInt(20)) / BigInt(100);
        const newBalance = await token.balanceOf(addr1.address);
        
        expect(newBalance - initialBalance).to.equal(expectedTGE);
      });

      it("should fail to release tokens when no tokens are vested", async function () {
        // First release TGE tokens
        await vesting.connect(addr1).releaseVestedTokens(vestingIdx);
        
        // Try to release again immediately - should fail as no new tokens are vested
        await expect(
          vesting.connect(addr1).releaseVestedTokens(vestingIdx)
        ).to.be.revertedWith("TokenVesting: cannot release tokens, no vested tokens");
        
        // Advance time but stay within cliff period
        await ethers.provider.send("evm_increaseTime", [vestingPlanParams.cliffPeriod / 2]);
        await ethers.provider.send("evm_mine");
        
        // Try to release during cliff period - should still fail
        await expect(
          vesting.connect(addr1).releaseVestedTokens(vestingIdx)
        ).to.be.revertedWith("TokenVesting: cannot release tokens, no vested tokens");
      });
    });

    describe("Unallocated Token Withdrawal", function () {
      let vestingIdx;

      beforeEach(async function () {
        // Create a vesting plan with more tokens than allocated to beneficiaries
        vestingPlanParams.totalTokenAmount = ethers.parseEther("1000");
        await vesting.addVestingPlansBulk(
          [vestingPlanParams],
          projectName,
          await token.getAddress()
        );
        const plans = await vesting.getVestingsByProjectName(projectName);
        vestingIdx = plans[0];
      });

      it("should fail when vesting plan is not initialized", async function () {
        const invalidVestingId = "0x" + "1".repeat(64); // Invalid UUID
        await expect(
          vesting.withdrawUnallocatedTokens(invalidVestingId)
        ).to.be.revertedWith("Invalid vesting plan");
      });

      it("should fail when there are no unallocated tokens to withdraw", async function () {
        // First withdraw should succeed
        await vesting.withdrawUnallocatedTokens(vestingIdx);

        // Second attempt should fail as there are no more tokens to withdraw
        await expect(
          vesting.withdrawUnallocatedTokens(vestingIdx)
        ).to.be.revertedWith("No unallocated tokens to withdraw");
      });

      it("should allow owner to withdraw unallocated tokens", async function () {
        const initialBalance = await token.balanceOf(owner.address);
        await vesting.withdrawUnallocatedTokens(vestingIdx);
        const newBalance = await token.balanceOf(owner.address);

        const allocatedAmount = ethers.parseEther("300"); // Sum of beneficiary amounts
        const totalAmount = ethers.parseEther("1000");
        const expectedWithdrawal = totalAmount - allocatedAmount;

        expect(newBalance - initialBalance).to.equal(expectedWithdrawal);
      });

      it("should not allow non-owner to withdraw tokens", async function () {
        await expect(
          vesting.connect(addr1).withdrawUnallocatedTokens(vestingIdx)
        ).to.be.revertedWith("Only vesting owner can withdraw tokens");
      });
    });

    describe("addVestingBeneficiaries function", function () {
      let vestingPlanParams;
      let vestingIdx;
      let projectName = "TestVestingProject";

      beforeEach(async function () {
        // Create a vesting plan with room for additional beneficiaries
        vestingPlanParams = {
          beneficiaries: [
            {
              beneficiaryAddress: addr1.address,
              tokenAmount: ethers.parseEther("100")
            }
          ],
          vestingPlanLabel: "Test Plan",
          saleStart: Math.floor(Date.now() / 1000),
          cliffPeriod: 90 * 24 * 60 * 60, // 90 days
          vestingPeriod: 365 * 24 * 60 * 60, // 1 year
          releasePeriod: 30 * 24 * 60 * 60, // 30 days
          tgePercent: 20,
          totalTokenAmount: ethers.parseEther("500") // Total amount higher than initial beneficiary amount
        };

        // Approve and add vesting plan
        await token.approve(await vesting.getAddress(), ethers.parseEther("500"));
        await vesting.addVestingPlansBulk(
          [vestingPlanParams],
          projectName,
          await token.getAddress()
        );

        const plans = await vesting.getVestingsByProjectName(projectName);
        vestingIdx = plans[0];
      });

      it("should allow adding new beneficiaries within allocation limit", async function () {
        const newBeneficiaries = [
          {
            beneficiaryAddress: addr2.address,
            tokenAmount: ethers.parseEther("200")
          }
        ];

        await vesting.addVestingBeneficiaries(vestingIdx, newBeneficiaries);

        // Verify beneficiary was added
        const beneficiaryVesting = await vesting.individualVestings(vestingIdx, addr2.address);
        expect(beneficiaryVesting[0]).to.equal(ethers.parseEther("200")); // tokenAmount
        expect(beneficiaryVesting[1]).to.equal(0); // releasedAmount
      });

      it("should fail when non-owner tries to add beneficiaries", async function () {
        const newBeneficiaries = [
          {
            beneficiaryAddress: addr2.address,
            tokenAmount: ethers.parseEther("200")
          }
        ];

        await expect(
          vesting.connect(addr1).addVestingBeneficiaries(vestingIdx, newBeneficiaries)
        ).to.be.revertedWith("Only vesting owner can add beneficiaries");
      });

      it("should fail with invalid vesting plan ID", async function () {
        const invalidVestingId = "0x" + "1".repeat(64); // Invalid UUID
        const newBeneficiaries = [
          {
            beneficiaryAddress: addr2.address,
            tokenAmount: ethers.parseEther("200")
          }
        ];

        await expect(
          vesting.addVestingBeneficiaries(invalidVestingId, newBeneficiaries)
        ).to.be.revertedWith("Invalid vesting plan");
      });

      it("should fail with zero address beneficiary", async function () {
        const newBeneficiaries = [
          {
            beneficiaryAddress: ethers.ZeroAddress,
            tokenAmount: ethers.parseEther("200")
          }
        ];

        await expect(
          vesting.addVestingBeneficiaries(vestingIdx, newBeneficiaries)
        ).to.be.revertedWith("Invalid beneficiary address");
      });

      it("should fail when exceeding total allocation", async function () {
        const newBeneficiaries = [
          {
            beneficiaryAddress: addr2.address,
            tokenAmount: ethers.parseEther("401") // Would exceed total of 500
          }
        ];

        await expect(
          vesting.addVestingBeneficiaries(vestingIdx, newBeneficiaries)
        ).to.be.revertedWith("Token allocation reached maximum for vesting plan");
      });

      it("should allow multiple beneficiaries in single transaction", async function () {
        const newBeneficiaries = [
          {
            beneficiaryAddress: addr2.address,
            tokenAmount: ethers.parseEther("150")
          },
          {
            beneficiaryAddress: addrs[0].address,
            tokenAmount: ethers.parseEther("150")
          }
        ];

        await vesting.addVestingBeneficiaries(vestingIdx, newBeneficiaries);

        // Verify both beneficiaries were added
        const beneficiary1Vesting = await vesting.individualVestings(vestingIdx, addr2.address);
        const beneficiary2Vesting = await vesting.individualVestings(vestingIdx, addrs[0].address);
        
        expect(beneficiary1Vesting[0]).to.equal(ethers.parseEther("150"));
        expect(beneficiary2Vesting[0]).to.equal(ethers.parseEther("150"));
      });
    });
  });
});