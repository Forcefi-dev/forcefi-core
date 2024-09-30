require("ethers");

async function main() {
    const [deployer] = await ethers.getSigners();

    console.log("Deploying contracts with the account:", deployer.address);

    const ForcefiToken = await ethers.deployContract("ERC20PausableToken", ["Forcefi token", "FORC", 1000000000]);
    console.log("ForcefiToken contract address " + await ForcefiToken.getAddress())
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
