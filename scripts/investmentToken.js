require("ethers");

async function main() {
    const [deployer] = await ethers.getSigners();

    console.log("Deploying contracts with the account:", deployer.address);

    const InvestmentToken = await ethers.deployContract("ArbitrumStaking", ["0x75C99B04292b35b08C55D8D4C267D91b4dbB906d",
        "0x75C99B04292b35b08C55D8D4C267D91b4dbB906d",
    "0x80fBEF0fb55885DAbfa38F0f3A5bF01A00F96b97",
    "0x6EDCE65403992e310A62460808c4b910D972f10f",
    deployer.address]);
    console.log("Investment token contract address " + await InvestmentToken.getAddress())
    // address _forcefiSilverNFTAddress, address _forcefiGoldNFTAddress, address _forcefiFundraisingAddress, address _endpoint, address _delegate
    // const InvestmentToken = await ethers.deployContract("ERC20BurnableToken", ["TEST", "TEST", 500, deployer.address]);
    // console.log("Investment token contract address " + await InvestmentToken.getAddress())

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });


