require("ethers");

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);

  const networkName = hre.network.name;
  const envVarName = `LZ_CONTRACT_ADDRESS_${networkName.toUpperCase()}`;
  const _lzContractAddress = process.env[envVarName];

  const ForcefiPackage = await ethers.deployContract("ForcefiPackage", [_lzContractAddress]);
  console.log("ForcefiPackage contract address " + await ForcefiPackage.getAddress())

  const ContractFactory = await ethers.deployContract("ContractFactory");
  const forcefiPackageAddress = await ForcefiPackage.getAddress();
  console.log("ContractFactory contract address " + await ContractFactory.getAddress())

  // const tx1 = await ContractFactory.setForcefiPackageAddress(forcefiPackageAddress);
  // await tx1.wait();
  // console.log("Package address for ContractFactory: " + await ContractFactory.getAddress() + " set to set to:", forcefiPackageAddress);

  const PausableContractFactory = await ethers.deployContract("PausableContractFactory");
  console.log("PausableContractFactory contract address " + await PausableContractFactory.getAddress())

  // const tx2 = await PausableContractFactory.setForcefiPackageAddress(forcefiPackageAddress);
  // await tx2.wait();
  // console.log("Package address for PausableContractFactory: " + await PausableContractFactory.getAddress() + " set to set to:", forcefiPackageAddress);

  const Fundraising = await ethers.deployContract("Fundraising");
  console.log("Fundraising contract address " + await Fundraising.getAddress())

  // const tx3 = await Fundraising.setForcefiPackageAddress(forcefiPackageAddress);
  // await tx3.wait();
  // console.log("Package address for Fundraising: " + await Fundraising.getAddress() + " set to set to:", forcefiPackageAddress);

  const Vesting = await ethers.deployContract("VestingFinal");
  console.log("Vesting contract address " + await Vesting.getAddress())

  // const tx4 = await Vesting.setForcefiPackageAddress(forcefiPackageAddress);
  // await tx4.wait();
  // console.log("Package address for Vesting: " + await Vesting.getAddress() + " set to set to:", forcefiPackageAddress);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
