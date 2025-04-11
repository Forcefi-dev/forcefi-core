require("ethers");

async function main() {
    const [deployer] = await ethers.getSigners();

    console.log("Deploying contracts with the account:", deployer.address);

    const SimpleNft = await ethers.deployContract("SimpleNFT", ["Silver Forcefi NFT", "Silver"]);
    console.log("SimpleNft contract address " + await SimpleNft.getAddress())
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
