require("ethers");

async function main() {
    const [deployer] = await ethers.getSigners();

    console.log("Deploying staking contract with the account:", deployer.address);

    const forcefiFundraisingAddress = "0x5622023bcAe407681F387852b3df62beCeA24950";
    const lzContractAddress = process.env.LZ_CONTRACT_ADDRESS_ARBITRUMSEPOLIA;

    const ChildStaking = await ethers.deployContract("ForcefiChildChainStaking", [forcefiFundraisingAddress, lzContractAddress, deployer.address]);
    console.log("ChildStaking staking address " + await ChildStaking.getAddress())
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
