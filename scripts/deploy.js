require("ethers");

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);

  const networkName = hre.network.name;
  const envVarName = `LZ_CONTRACT_ADDRESS_${networkName.toUpperCase()}`;
  const _lzContractAddress = process.env[envVarName];

  // const ForcefiPackage = await ethers.deployContract("ForcefiPackage", ["0x6EDCE65403992e310A62460808c4b910D972f10f", deployer.address]);
  // console.log("ForcefiPackage contract address " + await ForcefiPackage.getAddress())
  //
  const ContractFactory = await ethers.deployContract("ContractFactory");
  console.log("ContractFactory contract address " + await ContractFactory.getAddress())
  //
  // const PausableContractFactory = await ethers.deployContract("PausableContractFactory");
  // console.log("PausableContractFactory contract address " + await PausableContractFactory.getAddress())
  //
  // const Fundraising = await ethers.deployContract("Fundraising");
  // console.log("Fundraising contract address " + await Fundraising.getAddress())

  // const Vesting = await ethers.deployContract("Vesting");
  // console.log("Vesting contract address " + await Vesting.getAddress())

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
