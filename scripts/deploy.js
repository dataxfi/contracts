// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require('hardhat')

async function main() {
  const [deployer] = await ethers.getSigners();
  const UNIV2ROUTER_ADDRESS = "0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff";
  const VERSION = 1;

  console.log("Deploying contracts with the account:", deployer.address);

  console.log("Account balance:", (await deployer.getBalance()).toString());


  //const Adapter = await ethers.getContractFactory("UniV2Adapter");
  //const adapter = await Adapter.deploy(UNIV2ROUTER_ADDRESS, VERSION);
  //console.log("Adapter address:", adapter.address);


  const StakeRouter = await ethers.getContractFactory("StakeRouter");
  const stakeRouter = await StakeRouter.deploy();
  console.log("StakeRouter address:", stakeRouter.address); 

}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });