require("ethers");

async function main() {
    const [deployer] = await ethers.getSigners();

    console.log("Deploying contracts with the account:", deployer.address);

    const now = Math.floor(Date.now() / 1000) + 1800; // Current timestamp in seconds
    const oneMonth = now + 2592000; // One hour later

    console.log("NOW " + now);
    console.log("oneHourLater " + oneMonth);

    const InvestmentToken = await ethers.deployContract("LPYieldStaking", ["0x1e494710ddaF9d297C4DF9d11e6acc94ddA51A15",
        now, oneMonth, "1000000000000000000000000", "0x1e494710ddaF9d297C4DF9d11e6acc94ddA51A15", "0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14", "0x1238536071E1c677A632429e3655c799b22cDA52"]);
    console.log("Investment token contract address " + await InvestmentToken.getAddress())

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });


