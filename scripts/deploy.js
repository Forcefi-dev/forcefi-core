require("ethers");

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);

  const ContractFactory = await ethers.deployContract("VestingFinal");

  console.log("ERC20Token " + await ContractFactory.getAddress())

  await hre.run("verify:verify", {
    address: await ContractFactory.getAddress(),
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
