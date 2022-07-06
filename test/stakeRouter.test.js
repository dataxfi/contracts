require('dotenv').config();
const { expect, use } = require("chai");
const { ethers } = require("hardhat");
const { solidity } = require("ethereum-waffle");
const { isCallTrace } = require("hardhat/internal/hardhat-network/stack-traces/message-trace");
const { config } = require('./config');

use(solidity);

const chainId = process.env.chainId;
let owner, staker, beneficiary, referrer;
let feeAdmin;
let feeCalc;
let stakeCalc;
let stakeRouter;
let adapter;
let oceanToken;
let pool;
const UNIV2ROUTER_ADDRESS = config[chainId].UNI_V2_ROUTER_ADDRESS;
const POOL_ADDRESS = config[chainId].POOL_ADDRESS;
const OCEAN_ADDRESS = config[chainId].OCEAN_ADDRESS;
const WETH_ADDRESS = config[chainId].WETH_ADDRESS;
const USDT_ADDRESS = config[chainId].USDT_ADDRESS;
const VERSION = 1;
const STAKER_ADDRESS = config[chainId].USER_ADDRESS;
const REF_FEES = "10000000000000000";
const PROVIDER = config[chainId].PROVIDER;
let totalRefFee;

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

describe.only("Test Stake Router contract", function () {

  before("Prepare test environment", async function () {
    console.log("Chain ID - ", process.env.chainId);
    [owner, beneficiary, referrer] = await ethers.getSigners();


    const Adapter = await ethers.getContractFactory("UniV2Adapter");
    adapter = await Adapter.deploy(UNIV2ROUTER_ADDRESS);

    const FeeAdmin = await ethers.getContractFactory("FeeAdmin");
    feeAdmin = await FeeAdmin.deploy();
    console.log("FeeAdmin address:", feeAdmin.address);

    const FeeCalc = await ethers.getContractFactory("FeeCalc");
    feeCalc = await FeeCalc.deploy(feeAdmin.address);
    console.log("FeeCalc address:", feeCalc.address);

    const StakeCalc = await ethers.getContractFactory("StakeCalc");
    stakeCalc = await StakeCalc.deploy(feeCalc.address);
    console.log("StakeCalc address:", stakeCalc.address);

    const StakeRouter = await ethers.getContractFactory("StakeRouter");
    stakeRouter = await StakeRouter.deploy(feeCalc.address); 
    console.log("StakeRouter address:", stakeRouter.address);

    oceanToken = await ethers.getContractAt("IERC20V1", OCEAN_ADDRESS);
    usdtToken = await ethers.getContractAt("IERC20V1", USDT_ADDRESS);
    staker = await impersonateAddress(STAKER_ADDRESS);
    pool = await ethers.getContractAt("IERC20V1", POOL_ADDRESS);
    totalRefFee = ethers.BigNumber.from(0);

  });


  it("stake OCEAN tokens", async () => {

    let amountToStake = ethers.utils.parseEther('10');
    console.log("StakeCalc address - ", stakeCalc.address);
    let preCalcInfo =[[POOL_ADDRESS, staker.address, referrer.address, adapter.address],[amountToStake,REF_FEES, "0"],[OCEAN_ADDRESS]];
    let result = await stakeCalc.calcPoolOutGivenTokenIn(preCalcInfo);
    let poolAmountOut = result.poolAmountOut.toString();
    console.log("Pool Amount Out - ", poolAmountOut);
    let dataxFee = result.dataxFee;
    console.log("DataX Fee - ", dataxFee.toString());
    let refFee = result.refFee;
    console.log(" Ref Fee - ", refFee);
    totalRefFee = totalRefFee.add(refFee);

    console.log("Staker Address - ", staker.address);
    console.log("Staker Balance - ", (await oceanToken.balanceOf(staker.address)).toString());

    //approve amount to Stake
    await oceanToken.connect(staker).approve(stakeRouter.address, amountToStake);

    //check if allowance is gt or eq to amountToStake
    let allowance  = await oceanToken.allowance(staker.address, stakeRouter.address);
    console.log("Allowance - ", allowance.toString());
    expect(allowance).to.equal(amountToStake);

    let postCalcInfo =[[POOL_ADDRESS, staker.address, referrer.address, adapter.address],[amountToStake,REF_FEES, poolAmountOut],[OCEAN_ADDRESS]];
    let stakeRes = await stakeRouter.connect(staker).stakeTokenInDTPool(postCalcInfo);
  
    let actualPoolTokensOut = (await pool.balanceOf(staker.address)).toString();
    console.log(" Actual Pool Tokens Out  - ", actualPoolTokensOut);
    console.log("Pool Shares - ", actualPoolTokensOut);
    expect(actualPoolTokensOut).to.equal(poolAmountOut);

  });

  it("unstake OCEAN tokens", async () => {

    let poolSharesToUnstake = await pool.balanceOf(staker.address);
    console.log("Staker Pool Share Balance - ", poolSharesToUnstake.toString());
    let preCalcInfo =[[POOL_ADDRESS, staker.address, referrer.address, adapter.address],[poolSharesToUnstake, REF_FEES, "0"],[OCEAN_ADDRESS]];
    let result = await stakeCalc.calcTokenOutGivenPoolIn(preCalcInfo);
    let oceanOut = result.baseAmountOut;
    console.log("Expected OCEAN Amount Out - ", ethers.utils.formatUnits(oceanOut, 'wei'));
    let dataxFee = result.dataxFee;
    console.log("DataX Fee - ", dataxFee.toString());
    let refFee = result.refFee;
    console.log("Ref Fee - ", refFee.toString());
    totalRefFee = totalRefFee.add(refFee);

    //approve amount to Stake
    await pool.connect(staker).approve(stakeRouter.address, poolSharesToUnstake);
    
    //prepare data to send to unstake function
    let postCalcInfo =[[POOL_ADDRESS, staker.address, referrer.address, adapter.address],[poolSharesToUnstake, REF_FEES, oceanOut],[OCEAN_ADDRESS]];
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

  
  it("stake ETH", async () => {

    let amountToStake = ethers.utils.parseEther('1');
    let preCalcInfo =[[POOL_ADDRESS, staker.address, referrer.address, adapter.address],[amountToStake, REF_FEES, "0"],[WETH_ADDRESS, OCEAN_ADDRESS]];
    let result = await stakeCalc.calcPoolOutGivenTokenIn(preCalcInfo);
    let poolAmountOut = result.poolAmountOut.toString();
    console.log("Expected Pool Amount Out - ", poolAmountOut);
    let dataxFee = result.dataxFee;
    console.log("DataX Fee - ", dataxFee.toString());
    let refFee = result.refFee;
    console.log("Ref Fee - ", refFee.toString());
    totalRefFee = totalRefFee.add(refFee);

    console.log("Staker Address - ", staker.address);
    let stakerBalPreStake = await ethers.getDefaultProvider(PROVIDER).getBalance(staker.address);
    console.log("Staker Balance Pre-Stake : ", stakerBalPreStake.toString());
    expect(stakerBalPreStake).to.gte(amountToStake);
    //approve amount to Stake
    await oceanToken.connect(staker).approve(stakeRouter.address, amountToStake);
    
    //prepare data to send to stake function
    let postCalcInfo =[[POOL_ADDRESS, staker.address, referrer.address, adapter.address],[amountToStake,REF_FEES, poolAmountOut],[WETH_ADDRESS, OCEAN_ADDRESS]];
    //stake ETH in datapool 
    await stakeRouter.connect(staker).stakeETHInDTPool(postCalcInfo, {value: amountToStake});
    //check if staking was successful
    let actualPoolTokensOut = (await pool.balanceOf(staker.address)).toString();
    console.log("Pool Shares - ", actualPoolTokensOut);
    expect(actualPoolTokensOut).to.equal(poolAmountOut);

    let stakerBalPostStake = await ethers.getDefaultProvider(PROVIDER).getBalance(staker.address);
    console.log("Staker Balance Post-Stake : ", stakerBalPostStake.toString());
  });



  it("unstake ETH", async () => {

    let poolSharesToUnstake = await pool.balanceOf(staker.address);
    console.log("Staker Pool Share Balance - ", poolSharesToUnstake.toString());
    let preCalcInfo =[[POOL_ADDRESS, staker.address, referrer.address, adapter.address],[poolSharesToUnstake, REF_FEES, "0"],[OCEAN_ADDRESS, WETH_ADDRESS]];
    let result = await stakeCalc.calcTokenOutGivenPoolIn(preCalcInfo);
    let ethOut = result.baseAmountOut;
    console.log("Expected ETH Amount Out - ", ethers.utils.formatUnits(ethOut, 'wei'));
    let dataxFee = result.dataxFee;
    console.log("DataX Fee - ", dataxFee.toString());
    let refFee = result.refFee;
    console.log("Ref Fee - ", refFee.toString());
    totalRefFee = totalRefFee.add(refFee);

    //approve amount to Stake
    await pool.connect(staker).approve(stakeRouter.address, poolSharesToUnstake);
    
    //prepare data to send to unstake function
    let postCalcInfo =[[POOL_ADDRESS, staker.address, referrer.address, adapter.address],[poolSharesToUnstake, REF_FEES, ethOut],[OCEAN_ADDRESS, WETH_ADDRESS]];
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
    //expect(ethOut).to.equal(ethBalPostUnstake.sub(ethBalPreUnstake));
  });



  it("stake USDT", async () => {

    let amountToStake = ethers.utils.parseUnits('10', 'mwei');
    console.log("adapter address - ", adapter.address);
    let preCalcInfo =[[POOL_ADDRESS, staker.address, referrer.address, adapter.address],[amountToStake,REF_FEES, "0"],[USDT_ADDRESS, WETH_ADDRESS, OCEAN_ADDRESS]];
    console.log(preCalcInfo.toString());
    let result = await stakeCalc.calcPoolOutGivenTokenIn(preCalcInfo);
    console.log(result);
    let poolAmountOut = result.poolAmountOut.toString();
    console.log("Pool Amount Out - ", poolAmountOut);
    let dataxFee = result.dataxFee;
    console.log("DataX Fee - ", dataxFee.toString());
    let refFee = result.refFee;
    console.log(" Ref Fee - ", refFee.toString());
    totalRefFee = totalRefFee.add(refFee);

    console.log("Staker Address - ", staker.address);
    console.log("Staker Balance - ", (await usdtToken.balanceOf(staker.address)).toString());
    console.log("Amount to stake - ", amountToStake.toString());
    //approve amount to Stake
    await usdtToken.connect(staker).approve(stakeRouter.address, amountToStake);

    //check if allowance is gt or eq to amountToStake
    let allowance  = await usdtToken.allowance(staker.address, stakeRouter.address);
    console.log("Allowance - ", allowance.toString());
    expect(allowance).to.equal(amountToStake);

    let postCalcInfo =[[POOL_ADDRESS, staker.address, referrer.address, adapter.address],[amountToStake,REF_FEES, poolAmountOut],[USDT_ADDRESS, WETH_ADDRESS, OCEAN_ADDRESS]];
    let stakeRes = await stakeRouter.connect(staker).stakeTokenInDTPool(postCalcInfo);
    
    let actualPoolTokensOut = (await pool.balanceOf(staker.address)).toString();
    console.log(" Actual Pool Tokens Out  - ", actualPoolTokensOut);
    console.log("Pool Shares - ", actualPoolTokensOut);
    expect(actualPoolTokensOut).to.equal(poolAmountOut);

  });

  it("unstake USDT", async () => {

    let poolSharesToUnstake = await pool.balanceOf(staker.address);
    console.log("Staker Pool Share Balance - ", poolSharesToUnstake.toString());
    let preCalcInfo =[[POOL_ADDRESS, staker.address, referrer.address, adapter.address],[poolSharesToUnstake, REF_FEES, "0"],[OCEAN_ADDRESS, WETH_ADDRESS, USDT_ADDRESS]];
    let result = await stakeCalc.calcTokenOutGivenPoolIn(preCalcInfo);
    let usdtOut = result.baseAmountOut;
    console.log("Expected USDT Amount Out - ", ethers.utils.formatUnits(usdtOut, 'wei'));
    let dataxFee = result.dataxFee;
    console.log("DataX Fee - ", dataxFee.toString());
    let refFee = result.refFee;
    console.log("Ref Fee - ", refFee.toString());
    totalRefFee = totalRefFee.add(refFee);

    //approve amount to Stake
    await pool.connect(staker).approve(stakeRouter.address, poolSharesToUnstake);
    
    //prepare data to send to unstake function
    let postCalcInfo =[[POOL_ADDRESS, staker.address, referrer.address, adapter.address],[poolSharesToUnstake, REF_FEES, usdtOut],[OCEAN_ADDRESS, WETH_ADDRESS, USDT_ADDRESS]];
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

  it("claims Referrer Fees ", async() => {
    console.log("Expected Ref Fee to be claimed - ", totalRefFee.toString());
    const oceanInStakeRouterPreClaim = await oceanToken.balanceOf(stakeRouter.address);
    let txReceipt = await stakeRouter.claimRefFees(oceanToken.address, referrer.address);
    const actualFeeClaimed = await oceanToken.balanceOf(referrer.address);
    
    console.log("Actual Ref Fee claimed - ", actualFeeClaimed.toString());
    const oceanInStakeRouterPostClaim = await oceanToken.balanceOf(stakeRouter.address);
    expect(actualFeeClaimed).to.eq(totalRefFee);
    expect(oceanInStakeRouterPreClaim.sub(oceanInStakeRouterPostClaim)).to.eq(totalRefFee);
  })

});