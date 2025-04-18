require("ethers");
const { Options } = require('@layerzerolabs/lz-v2-utilities');


async function main() {
    const [deployer] = await ethers.getSigners();

    console.log("Start contract verification:", deployer.address);


    console.log('0x'.concat('0x80fBEF0fb55885DAbfa38F0f3A5bF01A00F96b97'.slice(2).padStart(64, '0')))


    const forcefiSilverNftAddress = "0x1e494710ddaF9d297C4DF9d11e6acc94ddA51A15";
    const forcefiGoldNftAddress = "0xae96b57c5e015c320641675B51B45d6d241288D4";
    const forcefiTokenAddress = "0xdEB4A034dE9d0935D4F4840026deB2F207aB946e";
    const forcefiFundraisingAddress = "0x59b006583C77173920a0FC62270243Cd4B6E2669";
    const lzContractAddress = process.env.LZ_CONTRACT_ADDRESS_ARBITRUMSEPOLIA;

    const addressToVerify = "0x090fEaeBeFc29D9F772759E81980F3f0B934df8f";

    // string memory _name, string memory _ticker, uint256 _initialSupply, address _ownerAddress
    await hre.run("verify:verify", {
        address: addressToVerify,
        constructorArguments: [
                "0x03f82b19f734cD92D093dB9C09512d271A7bD579",
         "0xae96b57c5e015c320641675B51B45d6d241288D4", "0x78F717B8dCf4A45dC20847DdFEbeaaBe43d10D0b", lzContractAddress, deployer.address],
    });
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
