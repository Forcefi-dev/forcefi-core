require("ethers");

async function main() {
    const [deployer] = await ethers.getSigners();

    console.log("Start contract verification:", deployer.address);

    const addressToVerify = "0x80026f366Fd5Fd4913CAcdF29d4B69d789aF99Ef";

    await hre.run("verify:verify", {
        address: addressToVerify,
        constructorArguments: [

        ],
    });
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
