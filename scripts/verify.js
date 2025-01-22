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

    const addressToVerify = "0x39BF161773c5C143C70fd7f9d3e5Ad8b0d1D362F";

    // string memory _name, string memory _ticker, uint256 _initialSupply, address _ownerAddress
    await hre.run("verify:verify", {
        address: addressToVerify,
        constructorArguments: ["0x3253193F7d1D3a1Ce5E27e8783c80890BC330467",
            "0x3253193F7d1D3a1Ce5E27e8783c80890BC330467",
            1734508754, 1734512354, "100000000000000000000000", 0],
    });
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
