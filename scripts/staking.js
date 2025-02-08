require("ethers");

async function main() {
    const [deployer] = await ethers.getSigners();

    console.log("Deploying staking contract with the account:", deployer.address);

    const forcefiSilverNftAddress = "0x1e494710ddaF9d297C4DF9d11e6acc94ddA51A15";
    const forcefiGoldNftAddress = "0xae96b57c5e015c320641675B51B45d6d241288D4";
    const forcefiTokenAddress = "0xdEB4A034dE9d0935D4F4840026deB2F207aB946e";
    const forcefiFundraisingAddress = "0x59b006583C77173920a0FC62270243Cd4B6E2669";
    const lzContractAddress = process.env.LZ_CONTRACT_ADDRESS_BASESEPOLIA;

    const AccessStaking = await ethers.deployContract("LPYieldStaking", [forcefiSilverNftAddress, forcefiGoldNftAddress, forcefiFundraisingAddress, lzContractAddress, deployer.address]);
    console.log("Access staking address " + await AccessStaking.getAddress())
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
