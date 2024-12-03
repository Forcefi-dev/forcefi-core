const { expect } = require("chai");

describe("Forcefi Child chain staking", function () {

    let owner, addr1, addr2;
    let silverNftAddress, goldNftAddress;
    const name = "Test token";
    const symbol = "TST";

    let stakingContract;
    let childChainStakingContract;

    const additionalTokens = "5000000";
    const investmentTokensMintAmount = "5000000";
    let forcefiToken;
    let investmentToken;
    const srcChainId = 1;
    const dstChainId = 2;

    beforeEach(async function () {

        const LZEndpointMock = await hre.ethers.getContractFactory("LZEndpointMock");
        const srcChainMock = await LZEndpointMock.deploy(srcChainId);
        const dstChainMock = await LZEndpointMock.deploy(dstChainId);

        const forcefiStaking = await hre.ethers.getContractFactory("ForcefiStaking");
        const forcefiChildChainStaking = await hre.ethers.getContractFactory("ForcefiChildChainStaking");

        [owner, addr1, addr2, silverNftAddress, goldNftAddress] = await ethers.getSigners();

        forcefiToken = await ethers.deployContract("ERC20BurnableToken", [name, symbol, additionalTokens, owner.address]);
        investmentToken = await ethers.deployContract("ERC20Token", [name, symbol, investmentTokensMintAmount, owner.address]);

        stakingContract = await forcefiStaking.deploy(silverNftAddress, goldNftAddress, forcefiToken, owner.address, srcChainMock.getAddress());
        childChainStakingContract = await forcefiChildChainStaking.deploy(owner.address, dstChainMock.getAddress());

        await srcChainMock.setDestLzEndpoint(childChainStakingContract.getAddress(), dstChainMock.getAddress());
        await dstChainMock.setDestLzEndpoint(stakingContract.getAddress(), srcChainMock.getAddress());

        await stakingContract.setTrustedRemote(dstChainId, childChainStakingContract.getAddress());
        await childChainStakingContract.setTrustedRemote(srcChainId, stakingContract.getAddress());
    });

    describe("testing forcefi child staking contract", function () {

        it("should set investor treshhold", async function () {

            const minStakingAmount = 500;
            const investorTreshhold = 7500;
            await stakingContract.setInvestorTreshholdAmount(investorTreshhold);

            await stakingContract.setMinStakingAmount(minStakingAmount);

            expect(await stakingContract.investorTreshholdAmount()).to.equal(investorTreshhold);

            const investors = await stakingContract.getInvestors();
            expect(investors.length).to.equal(0);

            await forcefiToken.approve(stakingContract.getAddress(), investorTreshhold);

            expect(await stakingContract.hasAddressStaked(owner.address)).to.equal(false);
            expect(await childChainStakingContract.hasAddressStaked(owner.address)).to.equal(false);

            await stakingContract.stake(investorTreshhold, 0);
            await stakingContract.bridgeStakingAccess([dstChainId], 0, 1, false);

            expect(await stakingContract.hasAddressStaked(owner.address)).to.equal(true);

            const investorsAfterEvent = await stakingContract.getInvestors();
            expect(investorsAfterEvent.length).to.equal(1);

            expect(await forcefiToken.balanceOf(owner.address)).to.equal(additionalTokens - investorTreshhold)
            expect(await forcefiToken.balanceOf(await stakingContract.getAddress())).to.equal(investorTreshhold)

            // Check child chain staking
            await childChainStakingContract.setInvestorTreshholdAmount(investorTreshhold);

            expect(await childChainStakingContract.hasAddressStaked(owner.address)).to.equal(true);
            const childChainInvestors = await childChainStakingContract.getInvestors();
            expect(childChainInvestors.length).to.equal(1);

            // Test _nonBlockingLzReceive that sets unstake
            await stakingContract.unstake(1, 0);
            expect(await stakingContract.hasAddressStaked(owner.address)).to.equal(false);

            expect(await childChainStakingContract.hasAddressStaked(owner.address)).to.equal(false);
            const childChainInvestorsAfterUnstake = await childChainStakingContract.getInvestors();
            expect(childChainInvestorsAfterUnstake.length).to.equal(0);
        });
    });
});
