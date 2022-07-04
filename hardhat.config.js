require('@nomiclabs/hardhat-waffle')
require('@nomiclabs/hardhat-etherscan')
require('dotenv').config()

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task('accounts', 'Prints the list of accounts', async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners()

  for (const account of accounts) {
    console.log(account.address)
  }
})

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  defaultNetwork: 'hardhat',
  networks: {
    hardhat: {
      forking: {
        url: "https://polygon-mainnet.g.alchemy.com/v2/9NFuHnOvVLrD3QiASu65G4fqh9AiDZl5",
        blockNumber: 29675155
      },
      allowUnlimitedContractSize: true
    },
   polygon: {
     chainId: 137,
      url: "https://polygon-mainnet.g.alchemy.com/v2/9NFuHnOvVLrD3QiASu65G4fqh9AiDZl5",
      accounts: [process.env.PK]
    },
    rinkeby: {
      chainId: 4,
      url: "https://rinkeby.infura.io/v3/24d5dee4acb04e0894c024bb6f7d3a6a",
      accounts: [process.env.PK]
    }
  },
  etherscan: {
    // Your API key for Etherscan
    // Obtain one at https://etherscan.io/
    apiKey: process.env.ETHSCAN_KEY
  },
  solidity: '0.8.12',
  optimizer: {
    enabled: true,
    runs: 500
  }

}
