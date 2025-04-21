const { expect } = require("chai");
const { ethers } = require('hardhat');

describe("CuratorContract", function () {
  let curatorContract;
  let mockFundraising;
  let mockERC20;
  let owner;
  let fundraisingOwner;
  let curator1;
  let curator2;
  let curator3;
  let nonOwner;
  let fundraisingId;

  beforeEach(async function () {
    // Get signers using ethers v6 syntax
    [owner, fundraisingOwner, curator1, curator2, curator3, nonOwner] = await ethers.getSigners();

    // Deploy mock ERC20 token with proper initialization
    const MockERC20 = await ethers.getContractFactory("MockERC20", owner);
    mockERC20 = await MockERC20.deploy("Mock Token", "MTK");
    await mockERC20.waitForDeployment();

    // Deploy mock fundraising contract
    const MockFundraising = await ethers.getContractFactory("MockFundraising", owner);
    mockFundraising = await MockFundraising.deploy();
    await mockFundraising.waitForDeployment();

    // Deploy curator contract
    const CuratorContract = await ethers.getContractFactory("CuratorContract", owner);
    curatorContract = await CuratorContract.deploy();
    await curatorContract.waitForDeployment();

    // Set fundraising address using the new contract address getter
    const fundraisingAddress = await mockFundraising.getAddress();
    await curatorContract.setFundraisingAddress(fundraisingAddress);

    // Set up mock fundraising instance
    fundraisingId = ethers.encodeBytes32String("test-fundraising"); // Updated from formatBytes32String
    await mockFundraising.setFundraisingOwner(fundraisingId, await fundraisingOwner.getAddress());
  });

  describe("Initialization", function () {
    it("Should set the correct owner", async function () {
      expect(await curatorContract.owner()).to.equal(await owner.getAddress());
    });

    it("Should set the correct fundraising address", async function () {
      expect(await curatorContract.fundraisingAddress()).to.equal(await mockFundraising.getAddress());
    });

    it("Should not allow setting zero address as fundraising address", async function () {
      await expect(
        curatorContract.setFundraisingAddress(ethers.ZeroAddress)
      ).to.be.revertedWith("Invalid fundraising address");
    });
  });

  describe("Access Control", function () {
    it("Should not allow non-owner to set fundraising address", async function () {
      await expect(
        curatorContract.connect(nonOwner).setFundraisingAddress(await mockFundraising.getAddress())
      ).to.be.revertedWithCustomError(curatorContract, "OwnableUnauthorizedAccount")
        .withArgs(await nonOwner.getAddress());
    });

    it("Should not allow non-fundraising-owner to add curators", async function () {
      const curators = [
        { curatorAddress: await curator1.getAddress(), percentage: 30 }
      ];
      await expect(
        curatorContract.connect(nonOwner).addCurators(fundraisingId, curators)
      ).to.be.revertedWith("Caller is not fundraising owner");
    });
  });

  describe("Get Curator Percentage", function () {
    beforeEach(async function () {
      const curators = [
        { curatorAddress: await curator1.getAddress(), percentage: 30 },
        { curatorAddress: await curator2.getAddress(), percentage: 20 }
      ];
      await curatorContract.connect(fundraisingOwner).addCurators(fundraisingId, curators);
    });

    it("Should return correct percentage for existing curator", async function () {
      const percentage = await curatorContract.getCuratorPercentage(fundraisingId, await curator1.getAddress());
      expect(percentage).to.equal(30);
    });

    it("Should return correct percentage for second curator", async function () {
      const percentage = await curatorContract.getCuratorPercentage(fundraisingId, await curator2.getAddress());
      expect(percentage).to.equal(20);
    });

    it("Should revert when curator does not exist", async function () {
      await expect(
        curatorContract.getCuratorPercentage(fundraisingId, await curator3.getAddress())
      ).to.be.revertedWith("Curator does not exist");
    });

    it("Should revert when checking non-existent fundraising", async function () {
      const nonExistentFundraisingId = ethers.encodeBytes32String("non-existent");
      await expect(
        curatorContract.getCuratorPercentage(nonExistentFundraisingId, await curator1.getAddress())
      ).to.be.revertedWith("Curator does not exist");
    });
  });

  describe("Adding Curators", function () {
    it("Should allow fundraising owner to add curators", async function () {
      const curators = [
        { curatorAddress: await curator1.getAddress(), percentage: 30 },
        { curatorAddress: await curator2.getAddress(), percentage: 20 }
      ];

      await curatorContract.connect(fundraisingOwner).addCurators(fundraisingId, curators);
      
      const totalPercentage = await curatorContract.getCurrentTotalPercentage(fundraisingId);
      expect(totalPercentage).to.equal(50);
    });

    it("Should fail when total percentage exceeds 100%", async function () {
      const curators = [
        { curatorAddress: await curator1.getAddress(), percentage: 60 },
        { curatorAddress: await curator2.getAddress(), percentage: 50 }
      ];

      await expect(
        curatorContract.connect(fundraisingOwner).addCurators(fundraisingId, curators)
      ).to.be.revertedWith("Total percentage exceeds 100%");
    });

    it("Should fail when adding duplicate curator", async function () {
      const curators = [
        { curatorAddress: await curator1.getAddress(), percentage: 30 }
      ];

      await curatorContract.connect(fundraisingOwner).addCurators(fundraisingId, curators);
      
      await expect(
        curatorContract.connect(fundraisingOwner).addCurators(fundraisingId, curators)
      ).to.be.revertedWith("Curator already exists");
    });

    it("Should fail when adding curator with zero address", async function () {
      const curators = [
        { curatorAddress: ethers.ZeroAddress, percentage: 30 }
      ];
      await expect(
        curatorContract.connect(fundraisingOwner).addCurators(fundraisingId, curators)
      ).to.be.revertedWith("Invalid curator address");
    });

    it("Should fail when adding curator with zero percentage", async function () {
      const curators = [
        { curatorAddress: await curator1.getAddress(), percentage: 0 }
      ];
      await expect(
        curatorContract.connect(fundraisingOwner).addCurators(fundraisingId, curators)
      ).to.be.revertedWith("Percentage must be greater than 0");
    });
  });

  describe("Removing Curators", function () {
    beforeEach(async function () {
      const curators = [
        { curatorAddress: await curator1.getAddress(), percentage: 30 },
        { curatorAddress: await curator2.getAddress(), percentage: 20 }
      ];
      await curatorContract.connect(fundraisingOwner).addCurators(fundraisingId, curators);
    });

    it("Should allow fundraising owner to remove curators", async function () {
      await curatorContract.connect(fundraisingOwner).removeCurators(fundraisingId, [await curator1.getAddress()]);
      
      expect(await curatorContract.isCurator(fundraisingId, await curator1.getAddress())).to.be.false;
    });

    it("Should fail when removing non-existent curator", async function () {
      await expect(
        curatorContract.connect(fundraisingOwner).removeCurators(fundraisingId, [await nonOwner.getAddress()])
      ).to.be.revertedWith("Curator does not exist");
    });

    it("Should correctly handle removing the last curator", async function () {
      await curatorContract.connect(fundraisingOwner).removeCurators(fundraisingId, [await curator2.getAddress()]);
      await curatorContract.connect(fundraisingOwner).removeCurators(fundraisingId, [await curator1.getAddress()]);
      expect(await curatorContract.getCurrentTotalPercentage(fundraisingId)).to.equal(0);
    });

    it("Should correctly handle removing multiple curators at once", async function () {
      await curatorContract.connect(fundraisingOwner).removeCurators(
        fundraisingId, 
        [await curator1.getAddress(), await curator2.getAddress()]
      );
      expect(await curatorContract.getCurrentTotalPercentage(fundraisingId)).to.equal(0);
    });

    it("Should fail when non-fundraising owner tries to remove curators", async function () {
      await expect(
        curatorContract.connect(nonOwner).removeCurators(fundraisingId, [await curator1.getAddress()])
      ).to.be.revertedWith("Caller is not fundraising owner");
    });
  });

  describe("Adjusting Curator Percentages", function () {
    beforeEach(async function () {
      const curators = [
        { curatorAddress: await curator1.getAddress(), percentage: 30 }
      ];
      await curatorContract.connect(fundraisingOwner).addCurators(fundraisingId, curators);
    });

    it("Should allow fundraising owner to adjust curator percentage", async function () {
      await curatorContract.connect(fundraisingOwner).adjustCuratorPercentage(fundraisingId, await curator1.getAddress(), 40);
      
      expect(await curatorContract.getCuratorPercentage(fundraisingId, await curator1.getAddress())).to.equal(40);
    });

    it("Should fail when new percentage would exceed 100%", async function () {
      await expect(
        curatorContract.connect(fundraisingOwner).adjustCuratorPercentage(fundraisingId, await curator1.getAddress(), 101)
      ).to.be.revertedWith("Total percentage would exceed 100%");
    });

    it("Should fail when adjusting percentage for non-existent curator", async function () {
      await expect(
        curatorContract.connect(fundraisingOwner).adjustCuratorPercentage(
          fundraisingId,
          await curator3.getAddress(),
          40
        )
      ).to.be.revertedWith("Curator does not exist");
    });

    it("Should fail when adjusting to zero percentage", async function () {
      await expect(
        curatorContract.connect(fundraisingOwner).adjustCuratorPercentage(
          fundraisingId,
          await curator1.getAddress(),
          0
        )
      ).to.be.revertedWith("Percentage must be greater than 0");
    });
  });

  describe("Fee Distribution and Claiming", function () {
    const distributionAmount = ethers.parseUnits("1000", 0);

    beforeEach(async function () {
      const curators = [
        { curatorAddress: await curator1.getAddress(), percentage: 60 },
        { curatorAddress: await curator2.getAddress(), percentage: 40 }
      ];
      await curatorContract.connect(fundraisingOwner).addCurators(fundraisingId, curators);
      
      // Set curator contract in mock fundraising
      await mockFundraising.setCuratorContract(await curatorContract.getAddress());
      
      // Fund the curator contract with tokens
      await mockERC20.mint(await curatorContract.getAddress(), distributionAmount);
      await mockERC20.connect(owner).approve(await curatorContract.getAddress(), distributionAmount);
    });

    it("Should correctly distribute fees to curators", async function () {
      await mockFundraising.distributeCuratorFees(
        await mockERC20.getAddress(),
        distributionAmount,
        fundraisingId
      );

      const curator1Share = (distributionAmount * BigInt(60)) / BigInt(100);
      const curator2Share = (distributionAmount * BigInt(40)) / BigInt(100);

      expect(await curatorContract.getUnclaimedFees(await curator1.getAddress(), await mockERC20.getAddress()))
        .to.equal(curator1Share);
      expect(await curatorContract.getUnclaimedFees(await curator2.getAddress(), await mockERC20.getAddress()))
        .to.equal(curator2Share);
    });

    it("Should allow curators to claim their fees", async function () {
      await mockFundraising.distributeCuratorFees(
        await mockERC20.getAddress(),
        distributionAmount,
        fundraisingId
      );

      const curator1Share = (distributionAmount * BigInt(60)) / BigInt(100);
      await curatorContract.connect(curator1).claimCuratorFees(await mockERC20.getAddress());

      expect(await mockERC20.balanceOf(await curator1.getAddress())).to.equal(curator1Share);
      expect(await curatorContract.getUnclaimedFees(await curator1.getAddress(), await mockERC20.getAddress()))
        .to.equal(0);
    });

    it("Should fail when non-fundraising contract tries to distribute fees", async function () {
      await expect(
        curatorContract.connect(nonOwner).receiveCuratorFees(
          await mockERC20.getAddress(),
          distributionAmount,
          fundraisingId
        )
      ).to.be.revertedWith("Only fundraising contract can distribute fees");
    });

    it("Should fail when trying to distribute zero amount", async function () {
      await expect(
        mockFundraising.distributeCuratorFees(
          await mockERC20.getAddress(),
          0,
          fundraisingId
        )
      ).to.be.revertedWith("Amount must be greater than 0");
    });

    it("Should fail when trying to distribute to empty curator list", async function () {
      const emptyFundraisingId = ethers.encodeBytes32String("empty-fundraising");
      await expect(
        mockFundraising.distributeCuratorFees(
          await mockERC20.getAddress(),
          distributionAmount,
          emptyFundraisingId
        )
      ).to.be.revertedWith("No curators to distribute fees to");
    });

    it("Should fail when claiming fees with zero balance", async function () {
      await expect(
        curatorContract.connect(curator3).claimCuratorFees(await mockERC20.getAddress())
      ).to.be.revertedWith("No fees to claim");
    });

    it("Should handle failed token transfer during claim", async function () {
      // First distribute fees
      await mockFundraising.distributeCuratorFees(
        await mockERC20.getAddress(),
        distributionAmount,
        fundraisingId
      );

      // Get curator contract's current balance
      const curatorContractAddress = await curatorContract.getAddress();
      const balance = await mockERC20.balanceOf(curatorContractAddress);

      // Move tokens out of the contract to simulate failed transfer
      // Create a failing ERC20 token contract to force transfer failure
      const MockFailingERC20 = await ethers.getContractFactory("MockFailingERC20", owner);
      const failingToken = await MockFailingERC20.deploy("Failing Token", "FTK");

      // Mint some tokens to the curator contract
      await failingToken.mint(curatorContractAddress, distributionAmount);

      // Set up unclaimed fees for the failing token
      await mockFundraising.distributeCuratorFees(
        await failingToken.getAddress(),
        distributionAmount,
        fundraisingId
      );

      // Now attempt to claim fees, which should fail due to transfer restriction
      await expect(
        curatorContract.connect(curator1).claimCuratorFees(await failingToken.getAddress())
      ).to.be.revertedWith("Fee transfer failed");
    });

    it("Should fail when fundraising address is not set", async function () {
      const newCuratorContract = await (await ethers.getContractFactory("CuratorContract")).deploy();
      await expect(
        newCuratorContract.connect(fundraisingOwner).addCurators(fundraisingId, [])
      ).to.be.revertedWith("Fundraising address not set");
    });

    it("Should handle distribution with single curator correctly", async function () {
      // Remove curator2
      await curatorContract.connect(fundraisingOwner).removeCurators(fundraisingId, [await curator2.getAddress()]);
      
      await mockFundraising.distributeCuratorFees(
        await mockERC20.getAddress(),
        distributionAmount,
        fundraisingId
      );

      expect(await curatorContract.getUnclaimedFees(await curator1.getAddress(), await mockERC20.getAddress()))
        .to.equal(distributionAmount * BigInt(60) / BigInt(100));
    });

    it("Should emit FeesReceived and FeesDistributed events", async function () {
      const tx = await mockFundraising.distributeCuratorFees(
        await mockERC20.getAddress(),
        distributionAmount,
        fundraisingId
      );

      await expect(tx)
        .to.emit(curatorContract, "FeesReceived")
        .withArgs(fundraisingId, await mockERC20.getAddress(), distributionAmount);

      const curator1Share = (distributionAmount * BigInt(60)) / BigInt(100);
      const curator2Share = (distributionAmount * BigInt(40)) / BigInt(100);

      await expect(tx)
        .to.emit(curatorContract, "FeesDistributed")
        .withArgs(fundraisingId, await curator1.getAddress(), curator1Share);

      await expect(tx)
        .to.emit(curatorContract, "FeesDistributed")
        .withArgs(fundraisingId, await curator2.getAddress(), curator2Share);
    });

    it("Should emit FeesClaimed event", async function () {
      await mockFundraising.distributeCuratorFees(
        await mockERC20.getAddress(),
        distributionAmount,
        fundraisingId
      );

      const curator1Share = (distributionAmount * BigInt(60)) / BigInt(100);
      await expect(curatorContract.connect(curator1).claimCuratorFees(await mockERC20.getAddress()))
        .to.emit(curatorContract, "FeesClaimed")
        .withArgs(await curator1.getAddress(), await mockERC20.getAddress(), curator1Share);
    });
  });

  describe("Event Emissions", function () {
    it("Should emit FundraisingAddressSet event", async function () {
      const newAddress = await mockFundraising.getAddress();
      await expect(curatorContract.setFundraisingAddress(newAddress))
        .to.emit(curatorContract, "FundraisingAddressSet")
        .withArgs(newAddress);
    });

    it("Should emit CuratorPercentageAdjusted event", async function () {
      const curators = [
        { curatorAddress: await curator1.getAddress(), percentage: 30 }
      ];
      await curatorContract.connect(fundraisingOwner).addCurators(fundraisingId, curators);

      await expect(curatorContract.connect(fundraisingOwner)
        .adjustCuratorPercentage(fundraisingId, await curator1.getAddress(), 40))
        .to.emit(curatorContract, "CuratorPercentageAdjusted")
        .withArgs(fundraisingId, await curator1.getAddress(), 30, 40);
    });
  });

  describe("Edge Cases", function () {
    it("Should handle getCurrentTotalPercentage for non-existent fundraising", async function () {
      const nonExistentFundraisingId = ethers.encodeBytes32String("non-existent");
      expect(await curatorContract.getCurrentTotalPercentage(nonExistentFundraisingId)).to.equal(0);
    });

    it("Should handle isCurator for non-existent fundraising", async function () {
      const nonExistentFundraisingId = ethers.encodeBytes32String("non-existent");
      expect(await curatorContract.isCurator(nonExistentFundraisingId, await curator1.getAddress())).to.be.false;
    });
  });
});
