const { expect } = require("chai");

describe("Forcefi staking", function () {

    let owner, addr1, addr2;
    let silverNftAddress, goldNftAddress;
    const name = "Test token";
    const symbol = "TST";

    let stakingContract;
    let dstForcefiPackage;

    const additionalTokens = "5000000";
    const investmentTokensMintAmount = "5000000";
    let forcefiToken;
    let investmentToken;

    beforeEach(async function () {
        const srcChainId = 1;
        const dstChainId = 2;

        const LZEndpointMock = await hre.ethers.getContractFactory("LZEndpointMock");
        const srcChainMock = await LZEndpointMock.deploy(srcChainId);
        const dstChainMock = await LZEndpointMock.deploy(dstChainId);

        const forcefiStaking = await hre.ethers.getContractFactory("ForcefiStaking");

        [owner, addr1, addr2, silverNftAddress, goldNftAddress] = await ethers.getSigners();

        forcefiToken = await ethers.deployContract("ERC20BurnableToken", [name, symbol, additionalTokens, owner.address]);
        investmentToken = await ethers.deployContract("ERC20Token", [name, symbol, investmentTokensMintAmount, owner.address]);

        stakingContract = await forcefiStaking.deploy(silverNftAddress, goldNftAddress, forcefiToken, owner.address, srcChainMock.getAddress());
        dstForcefiPackage = await forcefiStaking.deploy(silverNftAddress, goldNftAddress, forcefiToken, owner.address, dstChainMock.getAddress());
    });

    describe("testing forcefi staking contract", function () {

        it("should initialize staking with correct nft contract address values", async function () {
            expect(await stakingContract.silverNftContract()).to.equal(await silverNftAddress.getAddress());
            expect(await stakingContract.goldNftContract()).to.equal(await goldNftAddress.getAddress());
            expect(await stakingContract.forcefiTokenAddress()).to.equal(await forcefiToken.getAddress());
        });


        it("should set min staking amount", async function () {

            const stakingAmount = 500;
            await stakingContract.setMinStakingAmount(stakingAmount);

            expect(await stakingContract.minStakingAmount()).to.equal(stakingAmount);
            expect(await stakingContract.hasAddressStaked(owner.address)).to.equal(false);

            await forcefiToken.approve(stakingContract.getAddress(), stakingAmount);
            await stakingContract.stake(stakingAmount, 0);
            expect(await stakingContract.hasAddressStaked(owner.address)).to.equal(true);

            expect(await forcefiToken.balanceOf(owner.address)).to.equal(additionalTokens - stakingAmount)
            expect(await forcefiToken.balanceOf(await stakingContract.getAddress())).to.equal(stakingAmount)
        });

        it("should set curator treshhold", async function () {

            const curatorTreshhold = 2500;
            await stakingContract.setCuratorTreshholdAmount(curatorTreshhold);

            expect(await stakingContract.curatorTreshholdAmount()).to.equal(curatorTreshhold);

            expect(await stakingContract.isCurator(owner.address)).to.equal(false);
            await forcefiToken.approve(stakingContract.getAddress(), curatorTreshhold);
            await stakingContract.stake(curatorTreshhold, 0);
            expect(await stakingContract.hasAddressStaked(owner.address)).to.equal(true);
            expect(await stakingContract.isCurator(owner.address)).to.equal(true);
            expect(await forcefiToken.balanceOf(owner.address)).to.equal(additionalTokens - curatorTreshhold)
            expect(await forcefiToken.balanceOf(await stakingContract.getAddress())).to.equal(curatorTreshhold)

        });

        it("should set investor treshhold", async function () {

            const investorTreshhold = 7500;
            await stakingContract.setInvestorTreshholdAmount(investorTreshhold);

            expect(await stakingContract.investorTreshholdAmount()).to.equal(investorTreshhold);

            const investors = await stakingContract.getInvestors();
            expect(investors.length).to.equal(0);

            await forcefiToken.approve(stakingContract.getAddress(), investorTreshhold);
            await stakingContract.stake(investorTreshhold, 0);
            expect(await stakingContract.hasAddressStaked(owner.address)).to.equal(true);

            const investorsAfterEvent = await stakingContract.getInvestors();
            expect(investorsAfterEvent.length).to.equal(1);

            expect(await forcefiToken.balanceOf(owner.address)).to.equal(additionalTokens - investorTreshhold)
            expect(await forcefiToken.balanceOf(await stakingContract.getAddress())).to.equal(investorTreshhold)
        });

        it("should unstake the investor", async function () {

            const stakingAmount = 500;
            await stakingContract.setMinStakingAmount(stakingAmount);

            const curatorTreshhold = 2500;
            await stakingContract.setCuratorTreshholdAmount(curatorTreshhold);

            const investorTreshhold = 7500;
            await stakingContract.setInvestorTreshholdAmount(investorTreshhold);

            expect(await stakingContract.investorTreshholdAmount()).to.equal(investorTreshhold);

            await forcefiToken.approve(stakingContract.getAddress(), investorTreshhold);
            await stakingContract.stake(investorTreshhold, 0);
            expect(await stakingContract.hasAddressStaked(owner.address)).to.equal(true);

            const investorsAfterEvent = await stakingContract.getInvestors();
            expect(investorsAfterEvent.length).to.equal(1);

            expect(await forcefiToken.balanceOf(owner.address)).to.equal(additionalTokens - investorTreshhold)
            expect(await forcefiToken.balanceOf(await stakingContract.getAddress())).to.equal(investorTreshhold)

            // Unstake event
            await stakingContract.unstake(1, 0);

            expect(await stakingContract.hasAddressStaked(owner.address)).to.equal(false);
            expect(await stakingContract.isCurator(owner.address)).to.equal(false);

            const investorsAfterUnstakeEvent = await stakingContract.getInvestors();
            expect(investorsAfterUnstakeEvent.length).to.equal(0);

            expect(await forcefiToken.balanceOf(owner.address)).to.equal(additionalTokens)
            expect(await forcefiToken.balanceOf(await stakingContract.getAddress())).to.equal(0)
        });

        it("should distribute fees between investors", async function () {

            const investorTreshhold = 7500;
            const secondInvestorTokensInvested = 7500;
            await stakingContract.setInvestorTreshholdAmount(investorTreshhold);

            expect(await stakingContract.investorTreshholdAmount()).to.equal(investorTreshhold);

            const beginnerFeeThreshold = 100;

            const feesAmount = 50000;

            await forcefiToken.transfer(addr1, investorTreshhold);
            await forcefiToken.connect(addr1).approve(stakingContract.getAddress(), investorTreshhold);
            await stakingContract.connect(addr1).stake(investorTreshhold, 0);

            // Increase time so first investor has passed begginnerFeeThreshold
            await ethers.provider.send('evm_increaseTime', [beginnerFeeThreshold]);
            await ethers.provider.send('evm_mine');

            await forcefiToken.transfer(addr2, secondInvestorTokensInvested);
            await forcefiToken.connect(addr2).approve(stakingContract.getAddress(), secondInvestorTokensInvested);
            await stakingContract.connect(addr2).stake(secondInvestorTokensInvested, 0);

            expect(await forcefiToken.balanceOf(owner.address)).to.equal(additionalTokens - investorTreshhold - secondInvestorTokensInvested)
            expect(await forcefiToken.balanceOf(await stakingContract.getAddress())).to.equal(investorTreshhold + secondInvestorTokensInvested)

            const investors = await stakingContract.getInvestors();
            expect(investors.length).to.equal(2);

            await investmentToken.approve(stakingContract.getAddress(), feesAmount);
            await stakingContract.receiveFees(investmentToken, feesAmount)
            expect(await investmentToken.balanceOf(stakingContract.getAddress())).to.equal(Math.floor(feesAmount))

            expect(await stakingContract.getBalance(addr1, investmentToken)).to.equal(feesAmount / investors.length)
            expect(await stakingContract.getBalance(addr2, investmentToken)).to.equal(feesAmount / investors.length)

            await stakingContract.connect(addr1).claimFees(investmentToken)
            await stakingContract.connect(addr2).claimFees(investmentToken)

            expect(await investmentToken.balanceOf(addr1.address)).to.equal(feesAmount / investors.length)
            expect(await investmentToken.balanceOf(addr2.address)).to.equal(feesAmount / investors.length)
            expect(await investmentToken.balanceOf(owner.address)).to.equal(investmentTokensMintAmount - feesAmount)
        });
    });
});
