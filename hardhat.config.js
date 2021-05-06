require("@nomiclabs/hardhat-waffle");
require("hardhat-gas-reporter")
require("@nomiclabs/hardhat-etherscan")

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async () => {
  const accounts = await ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.6.6",
      }
    ],
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  gasReporter: {
    enabled: true,
  },
  networks: {
    hardhat: {
      allowUnlimitedContractSize: true,
      gasPrice: 8,
      blockGasLimit: 280000000000000,
    },
    binanceTestNet: {
      url: "https://data-seed-prebsc-1-s1.binance.org:8545",
      accounts: ["0x"],
      network_id: 97,
      confirmations: 10,
      timeoutBlocks: 200,
      skipDryRun: true
    },
    fantom: {
      url: "https://rpcapi.fantom.network",
      /* accounts: ["0x"], */
      network_id: 250,
      confirmations: 10,
      timeoutBlocks: 200,
      skipDryRun: true
    },
  },
  etherscan: {
    apiKey: "XXX"
  }
};

