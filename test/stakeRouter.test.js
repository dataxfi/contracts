require('dotenv').config();
const { expect, use } = require("chai");
const { ethers } = require("hardhat");
const { solidity } = require("ethereum-waffle");
const { isCallTrace } = require("hardhat/internal/hardhat-network/stack-traces/message-trace");
const { config } = require('./config');

use(solidity);

const chainId = process.env.chainId;
let owner, staker, beneficiary, referrer;
let storage;
let stakeRouter;
let adapter;
let oceanToken;
let pool;
const UNIV2ROUTER_ADDRESS = config[chainId].UNI_V2_ROUTER_ADDRESS;
const POOL_ADDRESS = config[chainId].POOL_ADDRESS;
const OCEAN_ADDRESS = config[chainId].OCEAN_ADDRESS;
const WETH_ADDRESS = config[chainId].WETH_ADDRESS;
const USDT_ADDRESS = config[chainId].USDT_ADDRESS;
const ADAPTER_VERSION = 1;
const STAKE_ROUTER_VERSION = 1;
const STAKER_ADDRESS = config[chainId].USER_ADDRESS;
const REF_FEES = "10000000000000000";
const PROVIDER = config[chainId].PROVIDER;

const impersonateAddress = async (address) => {
  const hre = require('hardhat');
  await hre.network.provider.request({
    method: 'hardhat_impersonateAccount',
    params: [address],
  });
  const signer = await ethers.provider.getSigner(address);
  signer.address = signer._address;
  return signer;
};

describe("Test Stake Router contract", function () {

  before("Prepare test environment", async function () {
    console.log("Chain ID - ", process.env.chainId);
    [owner, beneficiary, referrer] = await ethers.getSigners();
    const Storage = await ethers.getContractFactory("Storage");
    storage = await Storage.deploy();
    const admin = await storage.admin();
    console.log('Admin - ', admin);
    console.log('Owner - ', owner.address);
    expect(admin).to.equal(owner.address);

    const Adapter = await ethers.getContractFactory("UniV2Adapter");
    adapter = await Adapter.deploy(UNIV2ROUTER_ADDRESS, ADAPTER_VERSION);
    expect(await adapter.currentVersion()).to.equal(ADAPTER_VERSION);

    const StakeRouter = await ethers.getContractFactory("StakeRouter");
    stakeRouter = await StakeRouter.deploy(STAKE_ROUTER_VERSION, storage.address); 
    expect(await stakeRouter.version()).to.equal(STAKE_ROUTER_VERSION);

    oceanToken = await ethers.getContractAt("IERC20V1", OCEAN_ADDRESS);
    usdtToken = await ethers.getContractAt("IERC20V1", USDT_ADDRESS);
    staker = await impersonateAddress(STAKER_ADDRESS);
    pool = await ethers.getContractAt("IERC20V1", POOL_ADDRESS);

  });

/*
  it("allows to stake OCEAN tokens in data pools", async () => {

    let amountToStake = ethers.utils.parseEther('10');
    console.log("Stake Router version - ", await stakeRouter.version());
    console.log("adapter address - ", adapter.address);
    let preCalcInfo =[[POOL_ADDRESS, staker.address, referrer.address, adapter.address],["0",REF_FEES, amountToStake],[OCEAN_ADDRESS]];
    let result = await stakeRouter.calcPoolOutGivenTokenIn(preCalcInfo);
    let poolAmountOut = result.poolAmountOut.toString();
    console.log("Pool Amount Out - ", poolAmountOut);
    let dataxFee = result.dataxFee.toString();
    console.log("DataX Fee - ", dataxFee);
    let refFee = result.refFee.toString();
    console.log(" Ref Fee - ", refFee);

    console.log("Staker Address - ", staker.address);
    console.log("Staker Balance - ", (await oceanToken.balanceOf(staker.address)).toString());

    //approve amount to Stake
    await oceanToken.connect(staker).approve(stakeRouter.address, amountToStake);

    //check if allowance is gt or eq to amountToStake
    let allowance  = await oceanToken.allowance(staker.address, stakeRouter.address);
    console.log("Allowance - ", allowance.toString());
    expect(allowance).to.equal(amountToStake);

    let postCalcInfo =[[POOL_ADDRESS, staker.address, referrer.address, adapter.address],[poolAmountOut, REF_FEES, amountToStake],[OCEAN_ADDRESS]];
    let stakeRes = await stakeRouter.connect(staker).stakeTokenInDTPool(postCalcInfo);
    //let actualPoolTokensOut = stakeRes.poolTokensOut.toString();
    //console.log(" Actual Pool Tokens Out  - ", actualPoolTokensOut);
    let actualPoolTokensOut = (await pool.balanceOf(staker.address)).toString();
    console.log("Pool Shares - ", actualPoolTokensOut);
    expect(actualPoolTokensOut).to.equal(poolAmountOut);

  });

  it("allows to unstake OCEAN from data pools", async () => {

    let poolSharesToUnstake = await pool.balanceOf(staker.address);
    console.log("Staker Pool Share Balance - ", poolSharesToUnstake.toString());
    let preCalcInfo =[[POOL_ADDRESS, staker.address, referrer.address, adapter.address],["0", REF_FEES, poolSharesToUnstake],[OCEAN_ADDRESS]];
    let result = await stakeRouter.calcTokenOutGivenPoolIn(preCalcInfo);
    let oceanOut = result.baseAmountOut;
    console.log("Expected OCEAN Amount Out - ", ethers.utils.formatUnits(oceanOut, 'wei'));
    let dataxFee = result.dataxFee.toString();
    console.log("DataX Fee - ", dataxFee);
    let refFee = result.refFee.toString();
    console.log("Ref Fee - ", refFee);

    //approve amount to Stake
    await pool.connect(staker).approve(stakeRouter.address, poolSharesToUnstake);
    
    //prepare data to send to unstake function
    let postCalcInfo =[[POOL_ADDRESS, staker.address, referrer.address, adapter.address],[oceanOut, REF_FEES, poolSharesToUnstake],[OCEAN_ADDRESS]];
    //check if unstaking was successful
    let oceanBalPreUnstake = await oceanToken.balanceOf(staker.address);
    console.log("OCEAN balance before unstaking - ", oceanBalPreUnstake.toString());
    //unstake ETH from datapool 
    let txReceipt = await stakeRouter.connect(staker).unstakeTokenFromDTPool(postCalcInfo);
    const receipt = await ethers.provider.waitForTransaction(txReceipt.hash, 1, 1500000);
    
    //check if staking was successful
    let oceanBalPostUnstake = await oceanToken.balanceOf(staker.address);
    console.log("OCEAN balance after unstaking - ", oceanBalPostUnstake.toString());
    expect(oceanOut).to.equal(oceanBalPostUnstake.sub(oceanBalPreUnstake));
  });

  
  it("allows to stake ETH in data pools", async () => {

    let amountToStake = ethers.utils.parseEther('1');
    let preCalcInfo =[[POOL_ADDRESS, staker.address, referrer.address, adapter.address],["0", REF_FEES, amountToStake],[WETH_ADDRESS, OCEAN_ADDRESS]];
    let result = await stakeRouter.calcPoolOutGivenTokenIn(preCalcInfo);
    let poolAmountOut = result.poolAmountOut.toString();
    console.log("Expected Pool Amount Out - ", poolAmountOut);
    let dataxFee = result.dataxFee.toString();
    console.log("DataX Fee - ", dataxFee);
    let refFee = result.refFee.toString();
    console.log("Ref Fee - ", refFee);

    console.log("Staker Address - ", staker.address);
    let stakerBalPreStake = await ethers.getDefaultProvider(PROVIDER).getBalance(staker.address);
    console.log("Staker Balance Pre-Stake : ", stakerBalPreStake.toString());
    expect(stakerBalPreStake).to.gte(amountToStake);
    //approve amount to Stake
    await oceanToken.connect(staker).approve(stakeRouter.address, amountToStake);
    
    //prepare data to send to stake function
    let postCalcInfo =[[POOL_ADDRESS, staker.address, referrer.address, adapter.address],[poolAmountOut,REF_FEES, amountToStake],[WETH_ADDRESS, OCEAN_ADDRESS]];
    //stake ETH in datapool 
    await stakeRouter.connect(staker).stakeETHInDTPool(postCalcInfo, {value: amountToStake});
    //check if staking was successful
    let actualPoolTokensOut = (await pool.balanceOf(staker.address)).toString();
    console.log("Pool Shares - ", actualPoolTokensOut);
    expect(actualPoolTokensOut).to.equal(poolAmountOut);

    let stakerBalPostStake = await ethers.getDefaultProvider(PROVIDER).getBalance(staker.address);
    console.log("Staker Balance Post-Stake : ", stakerBalPostStake.toString());
  });



  it("allows to unstake ETH from data pools", async () => {

    let poolSharesToUnstake = await pool.balanceOf(staker.address);
    console.log("Staker Pool Share Balance - ", poolSharesToUnstake.toString());
    let preCalcInfo =[[POOL_ADDRESS, staker.address, referrer.address, adapter.address],["0", REF_FEES, poolSharesToUnstake],[OCEAN_ADDRESS, WETH_ADDRESS]];
    let result = await stakeRouter.calcTokenOutGivenPoolIn(preCalcInfo);
    let ethOut = result.baseAmountOut;
    console.log("Expected ETH Amount Out - ", ethers.utils.formatUnits(ethOut, 'wei'));
    let dataxFee = result.dataxFee.toString();
    console.log("DataX Fee - ", dataxFee);
    let refFee = result.refFee.toString();
    console.log("Ref Fee - ", refFee);

    //approve amount to Stake
    await pool.connect(staker).approve(stakeRouter.address, poolSharesToUnstake);
    
    //prepare data to send to unstake function
    let postCalcInfo =[[POOL_ADDRESS, staker.address, referrer.address, adapter.address],[ethOut, REF_FEES, poolSharesToUnstake],[OCEAN_ADDRESS, WETH_ADDRESS]];
     //check if unstaking was successful
    let ethBalPreUnstake = await ethers.getDefaultProvider(PROVIDER).getBalance(staker.address);
    console.log("Actual ETH before unstaking - ", ethBalPreUnstake.toString());
    //unstake ETH from datapool 
    let txReceipt = await stakeRouter.connect(staker).unstakeETHFromDTPool(postCalcInfo);
    const receipt = await ethers.provider.waitForTransaction(txReceipt.hash, 1, 1500000);
    console.log(receipt);
    //check if staking was successful
    let ethBalPostUnstake = await ethers.getDefaultProvider(PROVIDER).getBalance(staker.address);
    console.log("Actual ETH after unstaking - ", ethBalPostUnstake.toString());
    expect(ethOut).to.equal(ethBalPostUnstake.sub(ethBalPreUnstake));
  });

  */

  it("allows to stake USDT tokens in data pools", async () => {

    let amountToStake = ethers.utils.parseUnits('10', 'mwei');
    console.log("adapter address - ", adapter.address);
    let preCalcInfo =[[POOL_ADDRESS, staker.address, referrer.address, adapter.address],["0",REF_FEES, amountToStake],[USDT_ADDRESS, WETH_ADDRESS, OCEAN_ADDRESS]];
    let result = await stakeRouter.calcPoolOutGivenTokenIn(preCalcInfo);
    let poolAmountOut = result.poolAmountOut.toString();
    console.log("Pool Amount Out - ", poolAmountOut);
    let dataxFee = result.dataxFee.toString();
    console.log("DataX Fee - ", dataxFee);
    let refFee = result.refFee.toString();
    console.log(" Ref Fee - ", refFee);

    console.log("Staker Address - ", staker.address);
    console.log("Staker Balance - ", (await usdtToken.balanceOf(staker.address)).toString());
    console.log("Amount to stake - ", amountToStake.toString());
    //approve amount to Stake
    await usdtToken.connect(staker).approve(stakeRouter.address, amountToStake);

    //check if allowance is gt or eq to amountToStake
    let allowance  = await usdtToken.allowance(staker.address, stakeRouter.address);
    console.log("Allowance - ", allowance.toString());
    expect(allowance).to.equal(amountToStake);

    let postCalcInfo =[[POOL_ADDRESS, staker.address, referrer.address, adapter.address],[poolAmountOut, REF_FEES, amountToStake],[USDT_ADDRESS, WETH_ADDRESS, OCEAN_ADDRESS]];
    let stakeRes = await stakeRouter.connect(staker).stakeTokenInDTPool(postCalcInfo);
    //let actualPoolTokensOut = stakeRes.poolTokensOut.toString();
    //console.log(" Actual Pool Tokens Out  - ", actualPoolTokensOut);
    let actualPoolTokensOut = (await pool.balanceOf(staker.address)).toString();
    console.log("Pool Shares - ", actualPoolTokensOut);
    expect(actualPoolTokensOut).to.equal(poolAmountOut);

  });

  it("allows to unstake USDT from data pools", async () => {

    let poolSharesToUnstake = await pool.balanceOf(staker.address);
    console.log("Staker Pool Share Balance - ", poolSharesToUnstake.toString());
    let preCalcInfo =[[POOL_ADDRESS, staker.address, referrer.address, adapter.address],["0", REF_FEES, poolSharesToUnstake],[OCEAN_ADDRESS, WETH_ADDRESS, USDT_ADDRESS]];
    let result = await stakeRouter.calcTokenOutGivenPoolIn(preCalcInfo);
    let usdtOut = result.baseAmountOut;
    console.log("Expected USDT Amount Out - ", ethers.utils.formatUnits(usdtOut, 'wei'));
    let dataxFee = result.dataxFee.toString();
    console.log("DataX Fee - ", dataxFee);
    let refFee = result.refFee.toString();
    console.log("Ref Fee - ", refFee);

    //approve amount to Stake
    await pool.connect(staker).approve(stakeRouter.address, poolSharesToUnstake);
    
    //prepare data to send to unstake function
    let postCalcInfo =[[POOL_ADDRESS, staker.address, referrer.address, adapter.address],[usdtOut, REF_FEES, poolSharesToUnstake],[OCEAN_ADDRESS, WETH_ADDRESS, USDT_ADDRESS]];
    //check if unstaking was successful
    let usdtBalPreUnstake = await usdtToken.balanceOf(staker.address);
    console.log("USDT balance before unstaking - ", usdtBalPreUnstake.toString());
    //unstake ETH from datapool 
    let txReceipt = await stakeRouter.connect(staker).unstakeTokenFromDTPool(postCalcInfo);
    const receipt = await ethers.provider.waitForTransaction(txReceipt.hash, 1, 1500000);
    
    //check if staking was successful
    let usdtBalPostUnstake = await usdtToken.balanceOf(staker.address);
    console.log("USDT balance after unstaking - ", usdtBalPostUnstake.toString());
    expect(usdtOut).to.equal(usdtBalPostUnstake.sub(usdtBalPreUnstake));
  });

});