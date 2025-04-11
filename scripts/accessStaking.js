require("ethers");

async function main() {
    const [deployer] = await ethers.getSigners();

    console.log("Deploying staking contract with the account:", deployer.address);

    const forcefiTokenAddress = "0x1e494710ddaF9d297C4DF9d11e6acc94ddA51A15";
    const forcefiFundraisingAddress = "0x152C954F70E151D871B59280fC449458AcA025fe";
    const lzContractAddress = process.env.LZ_CONTRACT_ADDRESS_SEPOLIA;

    const AccessStaking = await ethers.deployContract("AccessStaking", [forcefiTokenAddress, forcefiFundraisingAddress, lzContractAddress, deployer.address]);
    console.log("Access staking address " + await AccessStaking.getAddress())
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
