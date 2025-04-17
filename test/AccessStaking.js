// const { expect } = require("chai");
// const { ethers } = require("hardhat");

// describe("AccessStaking", function () {
//     let accessStaking;
//     let forcefiToken;
//     let owner, addr1, addr2;
//     const name = "Forcefi Token";
//     const symbol = "FORC";
//     const initialSupply = ethers.parseEther("1000000");
//     const minStakingAmount = ethers.parseEther("100");
//     const curatorThreshold = ethers.parseEther("500");
//     const investorThreshold = ethers.parseEther("1000");

//     beforeEach(async function () {
//         [owner, addr1, addr2] = await ethers.getSigners();

//         // Deploy test ERC20 token
//         const ERC20Token = await ethers.getContractFactory("ERC20Token");
//         forcefiToken = await ERC20Token.deploy(name, symbol, initialSupply, owner.address);

//         // Deploy LayerZero endpoint mock
//         const LZEndpointMock = await ethers.getContractFactory("LZEndpointMock");
//         const endpoint = await LZEndpointMock.deploy(1); // chainId 1

//         // Deploy AccessStaking contract
//         const AccessStaking = await ethers.getContractFactory("AccessStaking");
//         accessStaking = await AccessStaking.deploy(
//             await forcefiToken.getAddress(),
//             owner.address, // mock fundraising address
//             await endpoint.getAddress(),
//             owner.address
//         );

//         // Setup remaining configuration
//         await accessStaking.setMinStakingAmount(minStakingAmount);
//         await accessStaking.setCuratorTreshholdAmount(curatorThreshold);
//         await accessStaking.setInvestorTreshholdAmount(investorThreshold);
        
//         // Setup token approvals
//         await forcefiToken.approve(accessStaking.getAddress(), initialSupply);
//         await forcefiToken.transfer(addr1.address, ethers.parseEther("10000"));
//         await forcefiToken.connect(addr1).approve(accessStaking.getAddress(), ethers.parseEther("10000"));
//     });

//     describe("Staking", function () {
//         it("should allow staking minimum amount", async function () {
//             await accessStaking.stake(minStakingAmount, owner.address);
//             expect(await accessStaking.hasAddressStaked(owner.address)).to.be.true;
//             expect(await forcefiToken.balanceOf(accessStaking.getAddress())).to.equal(minStakingAmount);
//         });

//         it("should allow becoming a curator", async function () {
//             await accessStaking.stake(curatorThreshold, owner.address);
//             expect(await accessStaking.isCurator(owner.address)).to.be.true;
//         });

//         it("should allow becoming an investor", async function () {
//             await accessStaking.stake(investorThreshold, owner.address);
//             const investors = await accessStaking.getInvestors();
//             expect(investors).to.include(owner.address);
//         });

//         it("should revert on invalid stake amount", async function () {
//             const invalidAmount = ethers.parseEther("50");
//             await expect(
//                 accessStaking.stake(invalidAmount, owner.address)
//             ).to.be.revertedWith("Invalid stake amount");
//         });
//     });

//     describe("Chain Management", function () {
//         beforeEach(async function () {
//             // Stake required amount first
//             await accessStaking.stake(minStakingAmount, owner.address);
//         });

//         it("should bridge staking access to new chain", async function () {
//             const chainId = 2;
//             const options = "0x";
//             await accessStaking.bridgeStakingAccess([chainId], options, false);
//             const chains = await accessStaking.getChainList(owner.address);
//             expect(chains[0]).to.equal(chainId);
//         });

//         it("should prevent adding duplicate chain", async function () {
//             const chainId = 2;
//             const options = "0x";
//             await accessStaking.bridgeStakingAccess([chainId], options, false);
//             await expect(
//                 accessStaking.bridgeStakingAccess([chainId], options, false)
//             ).to.be.revertedWith("Chain ID already added for this address");
//         });

//         it("should handle unstaking and chain removal", async function () {
//             const chainId = 2;
//             const options = "0x";
//             await accessStaking.bridgeStakingAccess([chainId], options, false);
//             await accessStaking.bridgeStakingAccess([], options, true);
//             expect(await accessStaking.hasAddressStaked(owner.address)).to.be.false;
//         });
//     });

//     describe("NFT Integration", function () {
//         it("should handle silver NFT staking through LayerZero", async function () {
//             const silverNftId = 1;
//             const payload = ethers.AbiCoder.defaultAbiCoder().encode(
//                 ["address", "uint256", "uint256"],
//                 [addr1.address, silverNftId, 0]
//             );

//             const origin = {
//                 srcEid: 1,
//                 sender: ethers.ZeroAddress,
//                 nonce: 1n
//             };

//             await accessStaking.connect(owner)._lzReceive(
//                 origin,
//                 ethers.ZeroHash,
//                 payload,
//                 ethers.ZeroAddress,
//                 "0x"
//             );
//             expect(await accessStaking.silverNftOwner(silverNftId)).to.equal(owner.address);
//         });

//         it("should handle gold NFT staking through LayerZero", async function () {
//             const goldNftId = 1;
//             const payload = ethers.AbiCoder.defaultAbiCoder().encode(
//                 ["address", "uint256", "uint256"],
//                 [addr1.address, 0, goldNftId]
//             );

//             const origin = {
//                 srcEid: 1,
//                 sender: ethers.ZeroAddress,
//                 nonce: 1n
//             };

//             await accessStaking.connect(owner)._lzReceive(
//                 origin,
//                 ethers.ZeroHash,
//                 payload,
//                 ethers.ZeroAddress,
//                 "0x"
//             );
//             expect(await accessStaking.goldNftOwner(goldNftId)).to.equal(addr1.address);
//         });
//     });
// });
