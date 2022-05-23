const { expect } = require("chai");
const { ethers } = require("hardhat");
const ERC20ABI = require("./ERC20-abi.json");

describe("uniswapV3", function () {
  it("Should swap the DAI to USDT", async function () {
	const USDC_ADDRESS = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"

	const DAI_ADDRESS = "0x6B175474E89094C44Da98b954EedeAC495271d0F"
	//console.log("fuck", await ethers.provider.getBalance(USDC_ADDRESS))
	const SWAP_ADDRESS = "0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45" 
	

   	const accounts = await ethers.getSigners();
	const ownerSign = accounts[accounts.length-1];
	//console.log(await ethers.provider.listAccounts())
	// deploy the contract
  	const UniswapV3 = await ethers.getContractFactory("Swap");
   	const uniswapV3 = await UniswapV3.deploy();
   	await uniswapV3.deployed();

	const owner = "0x8F9cfA5e735dCA900eE392B657dFEFbF3Af7FeCF";
	const USDC = new ethers.Contract(USDC_ADDRESS, ERC20ABI, ethers.provider);
	const DAI = new ethers.Contract(DAI_ADDRESS, ERC20ABI, ethers.provider);
	  //console.log(await USDC.balanceOf(owner))
	
	await USDC.connect(ownerSign).approve(uniswapV3.address, 1000*Math.pow(10, 6))
	//console.log(await USDC.allowance(owner,uniswapV3.address))	
	//DAIBalance = await DAI.balanceOf(owner);
	const beforeAmount = await DAI.balanceOf(owner)
	console.log(beforeAmount)
	  const amount = await uniswapV3.connect(ownerSign).swapExactInputSingle02(USDC_ADDRESS,DAI_ADDRESS,1000*Math.pow(10, 6))
	//console.log(amount)
	const afterAmount = await DAI.balanceOf(owner)
	console.log(afterAmount)
  });
});
