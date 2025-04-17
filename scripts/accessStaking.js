require("ethers");

async function main() {
    const [deployer] = await ethers.getSigners();

    console.log("Deploying staking contract with the account:", deployer.address);

    const forcefiTokenAddress = "0x1e494710ddaF9d297C4DF9d11e6acc94ddA51A15";
    const forcefiFundraisingAddress = "0x1856B00Cb8b75d5a001eE7F4DeE443c0415259c1";
    const lzContractAddress = process.env.LZ_CONTRACT_ADDRESS_ARBITRUMSEPOLIA;

    const AccessStaking = await ethers.deployContract("ArbitrumStaking", ["0x03f82b19f734cD92D093dB9C09512d271A7bD579",
         "0xae96b57c5e015c320641675B51B45d6d241288D4", "0x78F717B8dCf4A45dC20847DdFEbeaaBe43d10D0b", lzContractAddress, deployer.address]);
    console.log("Access staking address " + await AccessStaking.getAddress())
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
