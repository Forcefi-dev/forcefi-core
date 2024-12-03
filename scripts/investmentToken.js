require("ethers");

async function main() {
    const [deployer] = await ethers.getSigners();

    console.log("Deploying contracts with the account:", deployer.address);

    // const InvestmentToken = await ethers.deployContract("InvestmentToken", ["DAI", "DAI"]);
    // console.log("Investment token contract address " + await InvestmentToken.getAddress())

    const InvestmentToken = await ethers.deployContract("ERC20PausableBurnableToken", ["TEST", "TEST", 500, deployer.address]);
    console.log("Investment token contract address " + await InvestmentToken.getAddress())

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });


