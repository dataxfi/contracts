require('dotenv').config();
const { expect, use } = require("chai");
const { ethers } = require("hardhat");
const { solidity } = require("ethereum-waffle");
const { config } = require('./config');

use(solidity);

const chainId = process.env.chainId;
let owner, trader, beneficiary, referrer;
let storage;
let tradeRouter, poolRouter, freRouter, adapter;
let oceanToken;
let pool;
let poolDT;
const UNIV2ROUTER_ADDRESS = config[chainId].UNI_V2_ROUTER_ADDRESS;
const POOL_ADDRESS = config[chainId].POOL_ADDRESS;
const POOL2_ADDRESS = config[chainId].POOL2_ADDRESS;
const OCEAN_ADDRESS = config[chainId].OCEAN_ADDRESS;
const WETH_ADDRESS = config[chainId].WETH_ADDRESS;
const USPOOL_DT_ADDRESS = config[chainId].USPOOL_DT_ADDRESS;
const POOL_DT_ADDRESS = config[chainId].POOL_DT_ADDRESS;
const VERSION = 1;
const TRADER_ADDRESS = config[chainId].USER_ADDRESS;
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

describe("Test Trade Router contract", function () {

  before("Prepare test environment", async function () {
    console.log("Chain ID - ", process.env.chainId);
    [owner, beneficiary, referrer] = await ethers.getSigners();
    const Storage = await ethers.getContractFactory("Storage");
    storage = await Storage.deploy();
    const admin = await storage.admin();
    expect(admin).to.equal(owner.address);

    const Adapter = await ethers.getContractFactory("UniV2Adapter");
    adapter = await Adapter.deploy(UNIV2ROUTER_ADDRESS, VERSION);
    expect(await adapter.version()).to.equal(VERSION);

    const PoolRouter = await ethers.getContractFactory("PoolRouter");
    poolRouter = await PoolRouter.deploy(VERSION);
    expect(await poolRouter.version()).to.equal(VERSION);

    const FRERouter = await ethers.getContractFactory("FRERouter");
    freRouter = await FRERouter.deploy(VERSION);
    expect(await freRouter.version()).to.equal(VERSION);

    const TradeRouter = await ethers.getContractFactory("TradeRouter");
    tradeRouter = await TradeRouter.deploy(VERSION, storage.address, poolRouter.address, freRouter.address); 
    expect(await tradeRouter.version()).to.equal(VERSION);

    oceanToken = await ethers.getContractAt("IERC20V1", OCEAN_ADDRESS);
    usdtToken = await ethers.getContractAt("IERC20V1", USPOOL_DT_ADDRESS);
    trader = await impersonateAddress(TRADER_ADDRESS);
    pool = await ethers.getContractAt("IERC20V1", POOL_ADDRESS);
    poolDT = await ethers.getContractAt("IERC20V1", POOL_DT_ADDRESS);

  });

  

  it("1) Swap exact ETH -> DT", async () => {

    let amountToTrade = ethers.utils.parseEther('0.01');
    console.log("adapter address - ", adapter.address);

    let baseAmountNeeded = 0, dtAmountOut = 0;

    let preCalcInfo =[[POOL_ADDRESS, POOL_DT_ADDRESS, trader.address, referrer.address, adapter.address],[amountToTrade, baseAmountNeeded, dtAmountOut, REF_FEES],[WETH_ADDRESS, OCEAN_ADDRESS], false, ethers.utils.formatBytes32String("0")];
    let result = await tradeRouter.calcDatatokenOutGivenTokenIn(preCalcInfo);
    console.log(result);
    dtAmountOut = result.dtAmountOut.toString();
    console.log("DT Amount Out - ", dtAmountOut);
    baseAmountNeeded = result.baseAmountNeeded.toString();
    console.log("BaseAmountNeeded - ", baseAmountNeeded);
    let dataxFee = result.dataxFee.toString();
    console.log("DataX Fee - ", dataxFee);
    let refFee = result.refFee.toString();
    console.log("Ref Fee - ", refFee);

    console.log("Trader Address - ", trader.address);
    let dtBalPreTrade = (await poolDT.balanceOf(trader.address)).toString();
    console.log("DT balance post-trade - ", dtBalPreTrade.toString());
    let postCalcInfo =[[POOL_ADDRESS, POOL_DT_ADDRESS, trader.address, referrer.address, adapter.address],[amountToTrade, baseAmountNeeded, dtAmountOut, REF_FEES],[WETH_ADDRESS, OCEAN_ADDRESS], false, ethers.utils.formatBytes32String("0")];
    await oceanToken.connect(trader).approve(tradeRouter.address, baseAmountNeeded);
    let tradeRes = await tradeRouter.connect(trader).swapExactETHToDatatoken(postCalcInfo, {value: amountToTrade});
    console.log(tradeRes);
  
    let dtBalPostTrade = (await poolDT.balanceOf(trader.address)).toString();
    console.log("DT balance post-trade - ", dtBalPostTrade.toString());
    expect(dtBalPostTrade).to.equal(dtAmountOut);

  });
  
  

  it("2) Swap ETH -> exact DT", async () => {
    let amountToTrade = ethers.utils.parseEther('0.01');
    console.log("Adapter address - ", adapter.address);

    console.log("Pool address - ", POOL_ADDRESS);

    let baseAmountNeeded = 0, dtAmountOut = 0;

    let preCalcInfo =[[POOL_ADDRESS, POOL_DT_ADDRESS, trader.address, referrer.address, adapter.address],[amountToTrade, baseAmountNeeded, dtAmountOut, REF_FEES],[WETH_ADDRESS, OCEAN_ADDRESS], false, ethers.utils.formatBytes32String("0")];
    let result = await tradeRouter.calcTokenOutGivenDatatokenIn(preCalcInfo);
    console.log(result);
    dtAmountOut = result.tokenAmountOut.toString();
    console.log("DT Amount Out - ", dtAmountOut);
    baseAmountNeeded = result.baseAmountNeeded.toString();
    console.log("BaseAmountNeeded - ", baseAmountNeeded);
    let dataxFee = result.dataxFee.toString();
    console.log("DataX Fee - ", dataxFee);
    let refFee = result.refFee.toString();
    console.log("Ref Fee - ", refFee);

    console.log("Trader Address - ", trader.address);
    let dtBalPreTrade = (await poolDT.balanceOf(trader.address));
    console.log("DT balance pre-trade - ", dtBalPreTrade.toString());
    let postCalcInfo =[[POOL_ADDRESS, POOL_DT_ADDRESS, trader.address, referrer.address, adapter.address],[amountToTrade, baseAmountNeeded, dtAmountOut, REF_FEES],[WETH_ADDRESS, OCEAN_ADDRESS], false, ethers.utils.formatBytes32String("0")];
    await oceanToken.connect(trader).approve(tradeRouter.address, baseAmountNeeded);
    let tradeRes = await tradeRouter.connect(trader).swapETHToExactDatatoken(postCalcInfo, {value: amountToTrade});
    console.log(tradeRes);
  
    let dtBalPostTrade = (await poolDT.balanceOf(trader.address));
    console.log("DT balance post-trade - ", dtBalPostTrade.toString());
    expect((dtBalPostTrade.sub(dtBalPreTrade)).toString()).to.equal(dtAmountOut);

  });


  it("3) Swap exact OCEAN -> exact DT", async () => {
    let amountToTrade = ethers.utils.parseEther('10');
    console.log("adapter address - ", adapter.address);

    let baseAmountNeeded = 0, dtAmountOut = 0;

    let preCalcInfo =[[POOL_ADDRESS, POOL_DT_ADDRESS, trader.address, referrer.address, adapter.address],[amountToTrade, baseAmountNeeded, dtAmountOut, REF_FEES],[OCEAN_ADDRESS], false, ethers.utils.formatBytes32String("0")];
    let result = await tradeRouter.calcDatatokenOutGivenTokenIn(preCalcInfo);
    console.log(result);
    dtAmountOut = result.dtAmountOut.toString();
    console.log("DT Amount Out - ", dtAmountOut);
    baseAmountNeeded = result.baseAmountNeeded.toString();
    console.log("BaseAmountNeeded - ", baseAmountNeeded);
    let dataxFee = result.dataxFee.toString();
    console.log("DataX Fee - ", dataxFee);
    let refFee = result.refFee.toString();
    console.log("Ref Fee - ", refFee);

    console.log("Trader Address - ", trader.address);
    let dtBalPreTrade = await poolDT.balanceOf(trader.address);
    console.log("DT balance pre-trade - ", dtBalPreTrade.toString());
    let postCalcInfo =[[POOL_ADDRESS, POOL_DT_ADDRESS, trader.address, referrer.address, adapter.address],[amountToTrade, baseAmountNeeded, dtAmountOut, REF_FEES],[OCEAN_ADDRESS], false, ethers.utils.formatBytes32String("0")];
    await oceanToken.connect(trader).approve(tradeRouter.address, baseAmountNeeded);
    let allowance  = await oceanToken.allowance(trader.address, tradeRouter.address);
    console.log("Ocean token address - ", oceanToken.address);
    console.log("Trade Router allowance - ", allowance.toString());
    let tradeRes = await tradeRouter.connect(trader).swapExactTokenToDatatoken(postCalcInfo);
    
    console.log(tradeRes);
  
    let dtBalPostTrade = await poolDT.balanceOf(trader.address);
    console.log("DT balance post-trade - ", dtBalPostTrade.toString());
    expect((dtBalPostTrade.sub(dtBalPreTrade)).toString()).to.equal(dtAmountOut);

  });


  it("4) Swap OCEAN -> exact DT", async () => {
   
    let baseAmountNeeded = 0, 
    dtAmountOut = ethers.utils.parseEther('10'),
    tokenAmountIn = 0;

    let preCalcInfo =[[POOL_ADDRESS, POOL_DT_ADDRESS, trader.address, referrer.address, adapter.address],[tokenAmountIn, baseAmountNeeded, dtAmountOut, REF_FEES],[OCEAN_ADDRESS], false, ethers.utils.formatBytes32String("0")];
    let result = await tradeRouter.calcTokenInGivenDatatokenOut(preCalcInfo);
    console.log(result)
    tokenAmountIn = result.tokenAmountIn;
    console.log("Token Amount In - ", tokenAmountIn.toString());
    baseAmountNeeded = result.baseAmountNeeded;
    console.log("BaseAmountNeeded - ", baseAmountNeeded.toString());

    let dataxFee = result.dataxFee;
    console.log("DataX Fee - ", dataxFee.toString());
    let refFee = result.refFee;
    console.log("Ref Fee - ", refFee.toString());

    console.log("Trader Address - ", trader.address);
    let dtBalPreTrade = await poolDT.balanceOf(trader.address);
    console.log("DT balance pre-trade - ", dtBalPreTrade.toString());
    let postCalcInfo =[[POOL_ADDRESS, POOL_DT_ADDRESS, trader.address, referrer.address, adapter.address],[tokenAmountIn, baseAmountNeeded, dtAmountOut, REF_FEES],[OCEAN_ADDRESS], false, ethers.utils.formatBytes32String("0")];
    await oceanToken.connect(trader).approve(tradeRouter.address, postCalcInfo[1][0]);
    let allowance  = await oceanToken.allowance(trader.address, tradeRouter.address);
    console.log("Trade Router allowance - ", allowance.toString());
    let tradeRes = await tradeRouter.connect(trader).swapTokenToExactDatatoken(postCalcInfo);
    console.log(tradeRes);
  
    let dtBalPostTrade = await poolDT.balanceOf(trader.address);
    console.log("DT balance post-trade - ", dtBalPostTrade.toString());
    expect((dtBalPostTrade.sub(dtBalPreTrade)).toString()).to.equal(dtAmountOut);
  });


  
  it("5) Swap exact USDT -> DT", async () => {
    let amountToTrade = ethers.utils.parseUnits('10','mwei');
    console.log("adapter address - ", adapter.address);

    let baseAmountNeeded = 0, dtAmountOut = 0;

    let preCalcInfo =[[POOL_ADDRESS, POOL_DT_ADDRESS, trader.address, referrer.address, adapter.address],[amountToTrade, baseAmountNeeded, dtAmountOut, REF_FEES],[USPOOL_DT_ADDRESS,WETH_ADDRESS,OCEAN_ADDRESS], false, ethers.utils.formatBytes32String("0")];
    let result = await tradeRouter.calcDatatokenOutGivenTokenIn(preCalcInfo);
    console.log(result);
    dtAmountOut = result.dtAmountOut;
    console.log("DT Amount Out - ", dtAmountOut.toString());
    baseAmountNeeded = result.baseAmountNeeded;
    console.log("BaseAmountNeeded - ", baseAmountNeeded.toString());
    let dataxFee = result.dataxFee.toString();
    console.log("DataX Fee - ", dataxFee);
    let refFee = result.refFee.toString();
    console.log("Ref Fee - ", refFee);

    console.log("Trader Address - ", trader.address);
    let dtBalPreTrade = await poolDT.balanceOf(trader.address);
    console.log("DT balance pre-trade - ", dtBalPreTrade.toString());
    let postCalcInfo =[[POOL_ADDRESS, POOL_DT_ADDRESS, trader.address, referrer.address, adapter.address],[amountToTrade, baseAmountNeeded, dtAmountOut, REF_FEES],[USPOOL_DT_ADDRESS,WETH_ADDRESS,OCEAN_ADDRESS], false, ethers.utils.formatBytes32String("0")];
    await usdtToken.connect(trader).approve(tradeRouter.address, amountToTrade);
    let allowance  = await usdtToken.allowance(trader.address, tradeRouter.address);
    console.log("Trade Router allowance - ", allowance.toString());
    let tradeRes = await tradeRouter.connect(trader).swapExactTokenToDatatoken(postCalcInfo);
    
    console.log(tradeRes);
  
    let dtBalPostTrade = await poolDT.balanceOf(trader.address);
    console.log("DT balance post-trade - ", dtBalPostTrade.toString());
    expect((dtBalPostTrade.sub(dtBalPreTrade)).toString()).to.equal(dtAmountOut);

  });
  

  it("6) Swap USDT -> exact DT", async () => {
    let baseAmountNeeded = 0, 
    dtAmountOut = ethers.utils.parseEther('10'),
    tokenAmountIn = 0;

    let preCalcInfo =[[POOL_ADDRESS, POOL_DT_ADDRESS, trader.address, referrer.address, adapter.address],[tokenAmountIn, baseAmountNeeded, dtAmountOut, REF_FEES],[USPOOL_DT_ADDRESS,WETH_ADDRESS,OCEAN_ADDRESS], false, ethers.utils.formatBytes32String("0")];
    let result = await tradeRouter.calcTokenInGivenDatatokenOut(preCalcInfo);
    console.log(result)
    tokenAmountIn = result.tokenAmountIn;
    console.log("Token Amount In - ", tokenAmountIn.toString());
    baseAmountNeeded = result.baseAmountNeeded;
    console.log("BaseAmountNeeded - ", baseAmountNeeded.toString());

    let dataxFee = result.dataxFee;
    console.log("DataX Fee - ", dataxFee.toString());
    let refFee = result.refFee;
    console.log("Ref Fee - ", refFee.toString());

    console.log("Trader Address - ", trader.address);
    let dtBalPreTrade = await poolDT.balanceOf(trader.address);
    console.log("DT balance pre-trade - ", dtBalPreTrade.toString());
    let postCalcInfo =[[POOL_ADDRESS, POOL_DT_ADDRESS, trader.address, referrer.address, adapter.address],[tokenAmountIn, baseAmountNeeded, dtAmountOut, REF_FEES],[USPOOL_DT_ADDRESS,WETH_ADDRESS,OCEAN_ADDRESS], false, ethers.utils.formatBytes32String("0")];
    await usdtToken.connect(trader).approve(tradeRouter.address, postCalcInfo[1][0]);
    let allowance  = await usdtToken.allowance(trader.address, tradeRouter.address);
    console.log("Trade Router allowance - ", allowance.toString());
    let tradeRes = await tradeRouter.connect(trader).swapTokenToExactDatatoken(postCalcInfo);
    console.log(tradeRes);
  
    let dtBalPostTrade = await poolDT.balanceOf(trader.address);
    console.log("DT balance post-trade - ", dtBalPostTrade.toString());
    expect((dtBalPostTrade.sub(dtBalPreTrade)).toString()).to.equal(dtAmountOut);
  });

   /*
  it("7) Swap exact DT -> DT", async () => {});
  it("8) Swap DT -> exact DT", async () => {});//TODO
*/
 
  it("9) Swap exact DT -> USDT", async () => {

  });

  it("10) Swap DT -> exact USDT", async () => {});//TODO
  it("11) Swap exact DT -> OCEAN", async () => {});//TODO
  it("12) Swap DT -> exact OCEAN", async () => {});//TODO
  it("13) Swap exact DT -> ETH", async () => {});//TODO
  it("14) Swap DT -> exact ETH", async () => {});//TODO
  
  

});