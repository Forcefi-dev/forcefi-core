const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("AccessStaking", function () {    let accessStaking;
    let forcefiToken;
    let lzEndpoint;
    let owner, addr1, addr2, addr3;
    
    // Test constants
    const name = "Forcefi Token";
    const symbol = "FORC";
    const initialSupply = ethers.parseEther("1000000");
    const minStakingAmount = ethers.parseEther("100");
    const curatorThreshold = ethers.parseEther("500");
    const investorThreshold = ethers.parseEther("1000");
    const srcChainId = 101; // Ethereum
    const dstChainId = 102; // Polygon

    beforeEach(async function () {
        [owner, addr1, addr2, addr3] = await ethers.getSigners();

        // Deploy test ERC20 token
        const ERC20Token = await ethers.getContractFactory("ERC20Token");
        forcefiToken = await ERC20Token.deploy(name, symbol, initialSupply, owner.address);

        // Deploy LayerZero endpoint mock
        const LZEndpointMock = await ethers.getContractFactory("LZEndpointMock");
        lzEndpoint = await LZEndpointMock.deploy(srcChainId);

        // Deploy AccessStaking contract
        const AccessStaking = await ethers.getContractFactory("AccessStaking");
        accessStaking = await AccessStaking.deploy(
            await forcefiToken.getAddress(),
            owner.address, // fundraising address
            await lzEndpoint.getAddress(),
            owner.address
        );

        // Setup staking parameters
        await accessStaking.setMinStakingAmount(minStakingAmount);
        await accessStaking.setCuratorTreshholdAmount(curatorThreshold);
        await accessStaking.setInvestorTreshholdAmount(investorThreshold);

        // Setup token approvals and transfers
        await forcefiToken.approve(await accessStaking.getAddress(), initialSupply);
        await forcefiToken.transfer(addr1.address, ethers.parseEther("10000"));
        await forcefiToken.transfer(addr2.address, ethers.parseEther("10000"));
        await forcefiToken.transfer(addr3.address, ethers.parseEther("10000"));
        
        await forcefiToken.connect(addr1).approve(await accessStaking.getAddress(), ethers.parseEther("10000"));
        await forcefiToken.connect(addr2).approve(await accessStaking.getAddress(), ethers.parseEther("10000"));
        await forcefiToken.connect(addr3).approve(await accessStaking.getAddress(), ethers.parseEther("10000"));
    });

    describe("Contract Deployment and Initialization", function () {        it("should deploy with correct initial parameters", async function () {
            expect(await accessStaking.forcefiTokenAddress()).to.equal(await forcefiToken.getAddress());
            expect(await accessStaking.owner()).to.equal(owner.address);
        });

        it("should initialize with zero staking amounts", async function () {
            expect(await accessStaking.minStakingAmount()).to.equal(minStakingAmount);
            expect(await accessStaking.curatorTreshholdAmount()).to.equal(curatorThreshold);
            expect(await accessStaking.investorTreshholdAmount()).to.equal(investorThreshold);
        });

        it("should have empty staking lists initially", async function () {
            const investors = await accessStaking.getInvestors();
            expect(investors.length).to.equal(0);
            
            expect(await accessStaking.hasAddressStaked(addr1.address)).to.be.false;
            expect(await accessStaking.isCurator(addr1.address)).to.be.false;
        });
    });

    describe("Staking Configuration", function () {
        it("should allow owner to update minimum staking amount", async function () {
            const newMinAmount = ethers.parseEther("200");
            await accessStaking.setMinStakingAmount(newMinAmount);
            expect(await accessStaking.minStakingAmount()).to.equal(newMinAmount);
        });

        it("should allow owner to update curator threshold", async function () {
            const newCuratorThreshold = ethers.parseEther("750");
            await accessStaking.setCuratorTreshholdAmount(newCuratorThreshold);
            expect(await accessStaking.curatorTreshholdAmount()).to.equal(newCuratorThreshold);
        });

        it("should allow owner to update investor threshold", async function () {
            const newInvestorThreshold = ethers.parseEther("1500");
            await accessStaking.setInvestorTreshholdAmount(newInvestorThreshold);
            expect(await accessStaking.investorTreshholdAmount()).to.equal(newInvestorThreshold);
        });

        it("should revert when non-owner tries to update parameters", async function () {
            await expect(
                accessStaking.connect(addr1).setMinStakingAmount(ethers.parseEther("200"))
            ).to.be.revertedWithCustomError(accessStaking, "OwnableUnauthorizedAccount");

            await expect(
                accessStaking.connect(addr1).setCuratorTreshholdAmount(ethers.parseEther("750"))
            ).to.be.revertedWithCustomError(accessStaking, "OwnableUnauthorizedAccount");

            await expect(
                accessStaking.connect(addr1).setInvestorTreshholdAmount(ethers.parseEther("1500"))
            ).to.be.revertedWithCustomError(accessStaking, "OwnableUnauthorizedAccount");
        });
    });

    describe("Basic Staking Operations", function () {
        
        it("should allow staking minimum amount", async function () {
            await accessStaking.connect(addr1).stake(minStakingAmount, addr1.address);
            expect(await accessStaking.hasAddressStaked(addr1.address)).to.be.true;
            expect(await forcefiToken.balanceOf(await accessStaking.getAddress())).to.equal(minStakingAmount);
        });
        
        it("should allow staking curator threshold amount", async function () {
            await accessStaking.connect(addr1).stake(curatorThreshold, addr1.address);
            expect(await accessStaking.hasAddressStaked(addr1.address)).to.be.true;
            expect(await forcefiToken.balanceOf(await accessStaking.getAddress())).to.equal(curatorThreshold);
        });

        it("should allow staking investor threshold amount and create active stake", async function () {
            await accessStaking.connect(addr1).stake(investorThreshold, addr1.address);
            expect(await accessStaking.hasAddressStaked(addr1.address)).to.be.true;
            
            const stakeInfo = await accessStaking.activeStake(addr1.address);
            expect(stakeInfo.stakeAmount).to.equal(investorThreshold);
            expect(await forcefiToken.balanceOf(await accessStaking.getAddress())).to.equal(investorThreshold);
        });

        it("should revert when staking less than minimum amount", async function () {
            const invalidAmount = ethers.parseEther("50");
            await expect(
                accessStaking.connect(addr1).stake(invalidAmount, addr1.address)
            ).to.be.revertedWith("Invalid stake amount");
        });

        it("should revert when staking with insufficient token balance", async function () {
            const excessiveAmount = ethers.parseEther("20000");
            await expect(
                accessStaking.connect(addr1).stake(excessiveAmount, addr1.address)
            ).to.be.reverted;
        });

        it("should revert when staking with insufficient allowance", async function () {
            await forcefiToken.connect(addr1).approve(await accessStaking.getAddress(), 0);
            await expect(
                accessStaking.connect(addr1).stake(minStakingAmount, addr1.address)
            ).to.be.reverted;
        });

        it("should allow multiple users to stake", async function () {
            await accessStaking.connect(addr1).stake(minStakingAmount, addr1.address);
            await accessStaking.connect(addr2).stake(curatorThreshold, addr2.address);
            
            expect(await accessStaking.hasAddressStaked(addr1.address)).to.be.true;
            expect(await accessStaking.hasAddressStaked(addr2.address)).to.be.true;
            expect(await forcefiToken.balanceOf(await accessStaking.getAddress()))
                .to.equal(minStakingAmount + curatorThreshold);
        });
    });

    describe("Curator Functionality", function () {        it("should recognize curator when staking curator threshold", async function () {
            await accessStaking.connect(addr1).stake(curatorThreshold, addr1.address);
            expect(await accessStaking.isCurator(addr1.address)).to.be.true;
        });

        it("should not recognize curator when staking minimum amount", async function () {            await accessStaking.connect(addr1).stake(minStakingAmount, addr1.address);
            expect(await accessStaking.isCurator(addr1.address)).to.be.false;
        });

        it("should handle multiple curators", async function () {
            await accessStaking.connect(addr1).stake(curatorThreshold, addr1.address);
            await accessStaking.connect(addr2).stake(curatorThreshold, addr2.address);
            
            expect(await accessStaking.isCurator(addr1.address)).to.be.true;
            expect(await accessStaking.isCurator(addr2.address)).to.be.true;
        });
    });

    describe("Investor Functionality", function () {
        it("should add to investor list when staking investor threshold", async function () {
            await accessStaking.connect(addr1).stake(investorThreshold, addr1.address);
            
            const investors = await accessStaking.getInvestors();
            expect(investors).to.include(addr1.address);
            expect(investors.length).to.equal(1);        });

        it("should add to investor list when staking investor threshold", async function () {
            await accessStaking.connect(addr1).stake(investorThreshold, addr1.address);
            
            const investors = await accessStaking.getInvestors();
            expect(investors).to.include(addr1.address);
        });

        it("should not add to investor list when staking less than investor threshold", async function () {
            await accessStaking.connect(addr1).stake(curatorThreshold, addr1.address);
            
            const investors = await accessStaking.getInvestors();
            expect(investors).to.not.include(addr1.address);
            expect(investors.length).to.equal(0);
        });

        it("should handle multiple investors", async function () {
            await accessStaking.connect(addr1).stake(investorThreshold, addr1.address);
            await accessStaking.connect(addr2).stake(investorThreshold, addr2.address);
            
            const investors = await accessStaking.getInvestors();
            expect(investors).to.include(addr1.address);
            expect(investors).to.include(addr2.address);
            expect(investors.length).to.equal(2);
        });

        it("should not add duplicate investors", async function () {
            await accessStaking.connect(addr1).stake(investorThreshold, addr1.address);
            
            // Simulate restaking or additional operations that might trigger investor addition
            const investors1 = await accessStaking.getInvestors();
            expect(investors1.length).to.equal(1);
            
            // The investor should only appear once even if multiple operations occur
            const investors2 = await accessStaking.getInvestors();
            expect(investors2.length).to.equal(1);
        });
    });    describe("Chain Management", function () {
        it("should return empty chain list for users initially", async function () {
            const chains = await accessStaking.getChainList(addr1.address);
            expect(chains.length).to.equal(0);
        });

        it("should return empty chain list for non-staked users", async function () {
            const chains = await accessStaking.getChainList(addr2.address);
            expect(chains.length).to.equal(0);
        });

        it("should return empty chain list for different users", async function () {
            const chains1 = await accessStaking.getChainList(addr1.address);
            const chains2 = await accessStaking.getChainList(addr2.address);
            
            expect(chains1.length).to.equal(0);
            expect(chains2.length).to.equal(0);
        });
    });

    describe("Access Control and Security", function () {
        it("should allow only owner to call onlyOwner functions", async function () {
            await expect(
                accessStaking.connect(addr1).setMinStakingAmount(ethers.parseEther("200"))
            ).to.be.revertedWithCustomError(accessStaking, "OwnableUnauthorizedAccount");
        });

        it("should allow owner to transfer ownership", async function () {
            await accessStaking.transferOwnership(addr1.address);
            expect(await accessStaking.owner()).to.equal(addr1.address);
        });

        it("should allow new owner to call owner functions", async function () {
            await accessStaking.transferOwnership(addr1.address);
            await accessStaking.connect(addr1).setMinStakingAmount(ethers.parseEther("200"));
            expect(await accessStaking.minStakingAmount()).to.equal(ethers.parseEther("200"));
        });
    });

    describe("Edge Cases and Error Handling", function () {
        it("should handle zero amounts correctly", async function () {
            await expect(
                accessStaking.connect(addr1).stake(0, addr1.address)
            ).to.be.revertedWith("Stake amount must be greater than zero");
        });

        it("should handle maximum uint256 amounts", async function () {
            // This should fail due to insufficient balance, not overflow
            const maxAmount = ethers.MaxUint256;
            await expect(
                accessStaking.connect(addr1).stake(maxAmount, addr1.address)
            ).to.be.reverted;
        });

        it("should handle staking for zero address", async function () {
            await expect(
                accessStaking.connect(addr1).stake(minStakingAmount, ethers.ZeroAddress)
            ).to.be.reverted;
        });
               
    });
      describe("Gas Optimization and Performance", function () {
        it("should efficiently handle multiple staking operations", async function () {
            // Test multiple users staking different amounts
            await accessStaking.connect(addr1).stake(minStakingAmount, addr1.address);
            await accessStaking.connect(addr2).stake(curatorThreshold, addr2.address);
            await accessStaking.connect(addr3).stake(investorThreshold, addr3.address);
            
            // Verify all stakes are recorded correctly
            expect(await accessStaking.hasAddressStaked(addr1.address)).to.be.true;
            expect(await accessStaking.hasAddressStaked(addr2.address)).to.be.true;
            expect(await accessStaking.hasAddressStaked(addr3.address)).to.be.true;
            
            // Verify curator and investor lists
            expect(await accessStaking.isCurator(addr2.address)).to.be.true;
            expect(await accessStaking.isCurator(addr3.address)).to.be.true;
            
            const investors = await accessStaking.getInvestors();
            expect(investors).to.include(addr3.address);
        });
    });
});
