pragma solidity >=0.8.0 <0.9.0;
//SPDX-License-Identifier: BSU-1.1

import "../Base.sol";
import "../interfaces/IUniV2Adapter.sol";
import "../interfaces/IBPool.sol";
import "@openzeppelin/contracts/tokens/ERC20/IERC20.sol";
import "../interfaces/IStorage.sol";
import "../interfaces/ICommunityFeeCollector.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/tokens/ERC20/IERC20.sol";
import "../interface/IStorage.sol";
contract TradeRouter is Base , ICommunityFeeCollector,IUniswapV2Adapter , IStorage{
    using SafeMath for uint256;
    IUniV2Adapter adapter;
    ICommunityFeeCollector collector;
    uint256 public communityFee;
    uint public currentVersionTR;
    uint256 public tradingFees;
    constructor(address adapterAddress , address dtpoolAddress , uint _version , uint _fees,address  _StorageAddress, address _collectorAddress , address _tokenOcean ) {
        adapter = IUniV2Adapter(adapterAddress);
        IBPool dtpool = IBPool(dtPoolAddress);
        IStorage reg = IStorage(_StorageAddress);
        collector = ICommunityFeeCollector(_collectorAddress);
        currentVersion = _version;
        setCommunityFees(_fees);
        tokenOceanAddress = _tokenOcean;
        }
    modifier onlyGov {
        require(msg.sender == Owner());
    }
    
    
// getter function returning the community fees for the current state of the contracts.
    function getCommunityFees() public returns (uint256) {
        return(communityFees);
    }

    function getCurrentVersion() public returns (uint) {
        return(currentVersionTR);
    }

    // TODO: for now an single parameter , but can be created an array for finetuning the values
    function setCommunityFees(uint _fees ) public onlyGov {
        communityFee = _fees;
    }
    // @dev : address receiving the fees from the swapping operation
    function setCollector(address payable _feeCollector) public {
        require(collector.changeCollector(_feeCollector), "permission denied");
    }
  
    //@dev wrapper contract for storing the current version of TR with the corresponding address 
    function setVersionInStorage() public onlyOwner {
        return reg.upgradeContractAddresses(keccak256("versionTR", currentVersionTR),address(this));
    }

    /** @dev allows the swap between ETH to data token 
     @dev here we will follow tokens --> exact tokens --> exact DT and only swaps on the single side liquidity 
     just the difference is for the ETH we have the different function
    // @Param amountsOut = amount of data token needed .
    // and given the path is addr["WETH","OceanAddr","DTAddress"]. */
    function swapETHToExactDatatoken(
        uint256  tokenamountsOut,
        address[] calldata path,
        address datatoken,
        uint256 deadline
    ) external __lock__ payable returns(uint256 memory DToken_results)
     {
        // convert ETH to Ocean
        uint256 amountsOcean = adapter.swapETHtoExactTokens(
            amountsOut[0],
            path,
            deadline
        );


        address oceanToken = path[1];
        // convert Ocean to  exact Datatokens 
        //1. trying to determine the exactOcean tokens needed and the corresponding fees for getting the specific tokenAmounts out
        uint256[4] details = dtpool.getAmountInExactOut(path[1], path[2], tokenamountsOut, dtpool.getSwapFee());
        // thus necessary amounts of ocean needed.
        uint256 amountsOcean =  details[0];
       
       uint256 feesCollector =  getCommunityFees();
        uint256 OceanAmountSwapped =  sub(amountsOcean, feesCollector);
        IERC20(oceanToken).safeTransferFrom(oceanToken, feeCollector,  feesCollector);
        
        /*
        );
        */
        // now providing the parameters
        //  
        // array of addresses : tokenIn, tokenOut , marketfeeAddress
        address[3] tokenInOutMarket = [path[1], path[2],communityFeeCollector];
        //@param amountsInOutMaxFee array of ints: [maxAmountIn,tokenAmountOut,maxPrice, consumeMarketSwapFee]
        address[4] amountsInOutMaxFee = [OceanAmountSwapped, tokenamountsOut, 0,0 ];
        uint256[2] DToken_results =  dtpool.swapExactAmountOut(
           tokenInOutMarket,
           amountsInOutMaxFee
        );

        require(DToken_results[0], "swap unsuccessful");
    }


    //TODO : function swap ERC20 to exact DT
    function swapTokenToExactDatatoken(
        uint256  tokenamountsOut,
        address[] calldata path,
        address datatoken
    ) external  __lock__ payable{
        //  
    uint256 amountsOcean = adapter.swapTokentoExactTokens(
            amountsOut[0],
            path,
            deadline
        );


        address oceanToken = path[1];
        // convert Ocean to  exact Datatokens 
        //1. trying to determine the exactOcean tokens needed and the corresponding fees for getting the specific tokenAmounts out
        uint256[4] details = dtpool.getAmountInExactOut(path[1], path[2], tokenamountsOut, dtpool.getSwapFee());
        // thus necessary amounts of ocean needed.
        uint256 amountsOcean =  details[0];
       
       uint256 feesCollector =  getCommunityFees();
        uint256 OceanAmountSwapped =  sub(amountsOcean, feesCollector);
        IERC20(oceanToken).safeTransferFrom(oceanToken, feeCollector,  feesCollector);
        
        /*
        );
        */
        // now providing the parameters
        // array of addresses : tokenIn, tokenOut , marketfeeAddress
        address[3] tokenInOutMarket = [path[1], path[2],communityFeeCollector];
        //@param amountsInOutMaxFee array of ints: [maxAmountIn,tokenAmountOut,maxPrice, consumeMarketSwapFee]
        address[4] amountsInOutMaxFee = [OceanAmountSwapped, tokenamountsOut, 0,0 ];
        uint256[2] DToken_results =  dtpool.swapExactAmountOut(
           tokenInOutMarket,
           amountsInOutMaxFee
        );

        require(DToken_results[0], "swap unsuccessful");
    }



    function swapExactDatatokenforETH(
        uint256 ExactDataTokenIn,
        uint256 minAmountOut,
        address[] calldata path,
        address datatoken,
        uint256 deadline
    ) external {
        // first removing single side pair liquidity to retrive the ocean
      uint256 ExactOceanAmountOut =  dtpool.exitswapPoolAmountIn(ExactDataTokenIn, dtpool.getAmountOutExactIn(path[path.length - 1],datatoken,ExactDataTokenIn,0));
      
        // fees transfer
        uint256 feesCollector =  getCommunityFees();
        uint256 ExactOceanSwapped =  sub(ExactOceanAmountOut, feesCollector);
        IERC20(oceanToken).safeTransferFrom(oceanToken, feeCollector,  feesCollector); 

      // now converting the ocean to the ETH ad doing the transfer
        adapter.swapExactTokensForTokens(
        ExactOceanAmountOut,
        path,
        datatoken,
       0
        );

    }

    //TODO : function swap DT to exact ERC20
    function swapDatatokentoExactToken(
       uint256 ExactDataTokenIn,
        uint256 minAmountOut,
        address[] calldata path,
        address datatoken,
        uint256 deadline
    ) external {
        // flow : DT unstaked --> oceanToken --> ExactTokens 
        address erc20tokenOut = path[path.length - 1];
       dtpool.exitswapPoolAmountIn(
           ExactDataTokenIn,
           dtpool.getAmountOutExactIn(datatoken, path[path.length-1],0),
       );
    // now getting the same fees .
    
    
    
    }

    //TODO : function swap exact DT to ERC20
    function swapExactDatatokenToToken() external {
        //flow : similar but with tokens 

    }


    function swapDataTokenForExactTokens(
        address 


    ) externals returns(uint256 amountsOutIn)




    // @dev: this will be recursive call of SwapToken
    function swapDatatokenforDataToken(
        address datatokenIn,
        address amountInMax,
        address dataTokenOut,
    ) external returns (uint256 amountsDataOutMin) {
        swapDatatokenForExactTokens();
        swapExactTokenstoDataToken();


    }







}
