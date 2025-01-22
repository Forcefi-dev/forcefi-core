require("ethers");

async function main() {
    const [deployer] = await ethers.getSigners();

    console.log("Deploying contracts with the account:", deployer.address);

    const now = Math.floor(Date.now() / 1000) + 1800; // Current timestamp in seconds
    const oneMonth = now + 2592000; // One hour later

    console.log("NOW " + now);
    console.log("oneHourLater " + oneMonth);

    const InvestmentToken = await ethers.deployContract("SimpleRewards", ["0x1e494710ddaF9d297C4DF9d11e6acc94ddA51A15",
        "0x1e494710ddaF9d297C4DF9d11e6acc94ddA51A15",
        now, oneMonth, "1000000000000000000000000", 0]);
    console.log("Investment token contract address " + await InvestmentToken.getAddress())

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });


