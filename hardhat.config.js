require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 1000,
      },
    },
  },
  allowUnlimitedContractSize: true,
  networks: {
    sepolia: {
      url: process.env.SEPOLIA_RPC_URL,
      accounts: {
        mnemonic: process.env.MNEMONIC_TEST,
      },
    },
    mainnet: {
      url: process.env.MAINNET_RPC_URL,
      accounts: {
        mnemonic: process.env.MNEMONIC_TEST,
      },
    },
    lineaSepolia: {
      url: process.env.LINEA_SEPOLIA_RPC_URL,
      chainId: 59141,
      accounts: {
        mnemonic: process.env.MNEMONIC_TEST,
      },
    },
    arbitrumSepolia: {
      url: process.env.ARBITRUM_SEPOLIA_RPC_URL,
      chainId: 421614,
      accounts: {
        mnemonic: process.env.MNEMONIC_TEST,
      },
    },
  },
  etherscan: {
    apiKey: {
      mainnet: process.env.ETHERSCAN_API_KEY,
      sepolia: process.env.ETHERSCAN_API_KEY,
      lineaSepolia: process.env.LINEASCAN_API_KEY,
      arbitrumSepolia: process.env.ARBITRUM_API_KEY
    },
    customChains: [
      {
        network: "lineaSepolia",
        chainId: 59141,
        urls: {
          apiURL: "https://api-sepolia.lineascan.build/api",
          browserURL: "https://sepolia.lineascan.build/",
        },
      },
      {
        network: "arbitrumSepolia",
        chainId: 421614,
        urls: {
          apiURL: "https://api-sepolia.arbiscan.io/api",
          browserURL: "https://sepolia.arbiscan.io",
        },
      },
    ],
  },

}
