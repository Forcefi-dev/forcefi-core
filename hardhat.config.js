require("@nomicfoundation/hardhat-toolbox");
require('hardhat-deploy');
require("dotenv").config();
require("solidity-coverage");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 10,
      },
      viaIR: true,
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
    baseSepolia: {
      url: process.env.BASE_SEPOLIA_RPC_URL,
      chainId: 84532,
      accounts: {
        mnemonic: process.env.MNEMONIC_TEST,
      },
    },
    base: {
      url: process.env.BASE_RPC_URL,
      chainId: 8453,
      accounts: {
        mnemonic: process.env.MNEMONIC,
      },
    },
  },
  etherscan: {
    apiKey: {
      mainnet: process.env.ETHERSCAN_API_KEY,
      sepolia: process.env.ETHERSCAN_API_KEY,
      lineaSepolia: process.env.LINEASCAN_API_KEY,
      arbitrumSepolia: process.env.ARBITRUM_API_KEY,
      baseSepolia: process.env.BASE_API_KEY,
      base: process.env.BASE_API_KEY,
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
      {
        network: "baseSepolia",
        chainId: 84532,
        urls: {
          apiURL: "https://api-sepolia.basescan.org/api",
          browserURL: "https://sepolia.basescan.org/",
        },
      },
      {
        network: "base",
        chainId: 8453,
        urls: {
          apiURL: "https://api.basescan.org/api",
          browserURL: "https://basescan.org/",
        },
      },
    ],
  },

}
