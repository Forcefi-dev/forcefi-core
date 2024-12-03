require("ethers");
const { Options } = require('@layerzerolabs/lz-v2-utilities');


async function main() {
    const [deployer] = await ethers.getSigners();

    console.log("Start contract verification:", deployer.address);


    console.log('0x'.concat('0x80fBEF0fb55885DAbfa38F0f3A5bF01A00F96b97'.slice(2).padStart(64, '0')))


    const silverNftAddress = "0x233d98f5590471DBD3ef106beff290971A813092";
    const goldNftAddress = "0x233d98f5590471DBD3ef106beff290971A813092";
    const forcefiTokenAddress = "0x290E374362b6d36A0cfF86d682Db57845c913657";
    const forcefiFundraisingAddress = "0x357efaEf6fDdb79be305a01aBF15A4317004E23E";
    const lzContractAddress = process.env.LZ_CONTRACT_ADDRESS_ARBITRUMSEPOLIA;

    const addressToVerify = "0xC09291B33A6E7ba4D7c293D58a6683C1f9F2946C";

    // string memory _name, string memory _ticker, uint256 _initialSupply, address _ownerAddress
    await hre.run("verify:verify", {
        address: addressToVerify,
        constructorArguments: ["USDT", "USDT"],
    });
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
