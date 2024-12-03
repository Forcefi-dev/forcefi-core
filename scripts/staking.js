require("ethers");

async function main() {
    const [deployer] = await ethers.getSigners();

    console.log("Deploying staking contract with the account:", deployer.address);

    const silverNftAddress = "0x233d98f5590471DBD3ef106beff290971A813092";
    const goldNftAddress = "0x233d98f5590471DBD3ef106beff290971A813092";
    const forcefiTokenAddress = "0x290E374362b6d36A0cfF86d682Db57845c913657";
    const forcefiFundraisingAddress = "0x8A52CDCD89FAc778B2607085B4507e6CfE7e898A";
    const lzContractAddress = process.env.LZ_CONTRACT_ADDRESS_SEPOLIA;

    const ForcefiStaking = await ethers.deployContract("ForcefiStaking", [silverNftAddress, goldNftAddress, forcefiTokenAddress, forcefiFundraisingAddress, lzContractAddress]);
    console.log("Forcefi staking address " + await ForcefiStaking.getAddress())
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
