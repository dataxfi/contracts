pragma solidity >=0.8.0 <0.9.0;
//SPDX-License-Identifier: BSU-1.1

import "../Base.sol";
import "../interfaces/IUniV2Adapter.sol";
import "../interfaces/ITradeRouter.sol";
import "../interfaces/IPool.sol";
import "@openzeppelin/contracts/tokens/ERC20/IERC20.sol";
import "../interfaces/IStorage.sol";
import "../interfaces/ICommunityFeeCollector.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/tokens/ERC20/IERC20.sol";
contract TradeRouter is Base, ITradeRouter {
    using SafeMath for uint256;
    IUniV2Adapter adapter;
    ICommunityFeeCollector collector;
    uint256 public communityFee;
    uint public currentVersionTR;
    // adding publishing marketting address (which will be getting the fees for every swap with the datatoken).
    address public publishMarketAddress;
    constructor(address adapterAddress , address dtpoolAddress , uint _version , uint _fees,address  _StorageAddress, address _collectorAddress, address _publishingMarketingAddress ) {
        adapter = IUniV2Adapter(adapterAddress);
        IPool dtpool = IPool(dtPoolAddress);
        IStorage reg = IStorage(_StorageAddress);
        collector = ICommunityFeeCollector(_collectorAddress);
        currentVersion = _version;
        setParam(_fees);
        }
    modifier onlyGov {
        require(msg.sender == Owner());
    }
    
    
// getter function returning the community fees 
    function getSwapFees() public returns (uint256) {
        return(reg.getStateParams(keccak256("swapFees"),currentVersionTR));
    }

    function getCurrentVersion() public returns (uint) {
        return(currentVersionTR);
    }

    // @dev : address receiving the fees from the swapping operation
    function setCollector(address payable _feeCollector) public {
        require(collector.changeCollector(_feeCollector), "permission denied");
    }
  
    //@dev wrapper contract for storing the current state values 
    function setParamUint(uint256 newParameter) public onlyGov {
        return reg.upgradeStateParameters(keccak256(variable_name, currentVersionTR), newParameter);
    }
    function swapETHToExactDatatoken(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 refFees,
        address refAddress,
        uint256 deadline
    ) external __lock__ payable {
        // convert ETH to Ocean/H20 or other baseToken in the given dtpool. 
        address[2] pathOne = [path[0], path[1]];
        uint256 amountsOcean = adapter.swapETHtoExactTokens(
            amountsOut[0],
            pathOne,
            deadline
        );
        // convert Ocean to Datatokens 
        // indexing will be from 0
        address dataToken = path[path.length - 1];

        // to be send to the feeCollector and the rest is to be converted 
         uint256 feesCollector = mul(amountsOcean, getSwapFees());
        uint256 OceanAmountSwapped =  sub(amountsOcean, feesCollector);
        /** tokenInOutAddress = [tokenIn, tokenOut, consumeMarketFeeAddress]
        amountsInOutMaxFee = [maxAmountIn,tokenAmountOut,maxPrice, consumeMarketSwapFee].
        */
    uint256 maxPrice = dtpool.getSpotPrice(path[0],path[path.length - 1], dtpool.getSwapFee());
       address[3] tokenInOutAddress = [path[1],path[path.length - 1],dtpool.getSwapFee()];
       address[4] amountsInOutMaxFee = [amountInMax, amountOut, maxPrice, dtpool.getSwapFee() ];
        // and then finally staking to the data token
       dtpool.swapExactAmountOut(
            tokenInOutAddress,
            amountsInOutmaxFee
        );

        collector.withdrawToken(dataToken);    

    }


    function swapExactETHforDataTokens(
        uint256 amounIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 refFees,
        address refAddress,
        uint256 deadline
    ) public __lock__ payable  override {
        // conversion from  the ETH to the given baseToken
        uint256 amountsOcean = adapter.swapExactETHtoTokens(
        amountOutMin,
        path,
         to,
        deadline
        );
      address dataToken = path[path.length - 1];
        // to be send to the feeCollector and the rest is to be converted 
         uint256 feesCollector = mul(amountsOcean, getSwapFees());
        uint256 OceanAmountSwapped =  sub(amountsOcean, feesCollector);

       uint256 maxPrice = dtpool.getSwapFee(path[0],path[path.length - 1], dtpool.getSwapFee() );
       address[3] tokenInOutAddress = [path[0],path[path.length - 1],dtpool.getSwapFee()];
       address[4] amountsInOutMaxFee = [amountInMax, amountOut, maxPrice, dtpool.getSwapFee() ];
        // and then finally staking to the data token
       dtpool.swapExactAmountOut(
            tokenInOutAddress,
            amountsInOutmaxFee
        );
        collector.withdrawToken(dataToken);    


    }


    //TODO : function swap ERC20 to exact DT
    function swapTokenToExactDatatoken(
        address dtpoolAddress,
        uint256[] calldata amountsOut,
        address[] calldata path,
        address datatoken,
        uint256 deadline
    ) external  __lock__ payable{
        
       uint256 amounts = adapter.swapExactTokensForTokens(AmountIn, amountOutMin, path, to, deadline);
       address dataToken = path[path.length - 1];
        dtpool.swapExactAmountIn(
            dataToken,
            amounts,
            datatoken,
            amountsOut[1],
            0 //maxPrice
        );


        

    }

    function swapExactTokensforDataTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 refFees,
        address refAddress,
        uint256 deadline
    ) external  __lock__ payable {
        // path is between the baseToken and datatoken.

        address[2] pathOne = [path[0], path[1]];
        uint256 amountsOcean = adapter.swapExactTokenstoTokens(
         amountIn,
         amountOutMin,
         pathOne,
         to,
         deadline
        );
       address dataToken = path[path.length - 1];
        // to be send to the feeCollector and the rest is to be converted 
         uint256 feesCollector = mul(amountsOcean, CollectorFees());
        uint256 OceanAmountSwapped =  sub(amountsOcean, feesCollector);

    }

    

    //TODO : function swap DT to exact ERC20
    function swapDatatokenToExactToken(
        address datatoken,
        address maxAmountIn,
        address[] calldata path,
        uint256 deadline

    ) external {
        // flow : DT unstaked --> dataToken --> ExactTokens 
        address erc20tokenOut = path[path.length - 1];
        swap.swapExactAmountOut(datatoken, maxAmountIn,erc20tokenOut, deadline);
    }





function  swapExactDatatokensforDatatokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 refFees,
        address refAddress,
        uint256 deadline
    ) __lock__ public {

        address[] newPath;
        // swapping out exactDT to the tokens 
        swapExactDatatokensforTokens(
            amountIn,
            dtpool.getAmountOutExactIn(path[0],path[1], amountIn, getSwapFees()),
            [path[0], path[1]],
            address(this),
            

        );



    }
//@dev here swapp fees accured will be two times , so no need of fees accural sepearately.
 function swapDatatokensforExactDatatokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline,
        uint256 refFees,
        address refAddress
    ) 
    {
        address[] newPath;

        swapDatatokensforExactTokens(
            amountInMax,
            getAmountOutMaxIn(path[0], path[1], amountInMax, getSwapFees()),
            [path[0] ,path[1]],
            address(this),
            deadline,
            refFees,
            refAddress
        );
        // now we will be recursively calling the function to swap the dataToken to the given  destination address
        /**
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 refFees,
        address refAddress,
        uint256 deadline
         */
       uint256 baseTokenAmountIn = (IERC20(datatokenAmountIn).BalanceOf(path[1]);


        for(int i = 1; i < path[path.length - 1]; i++)
        {
            newPath.push(path[i]);
        }
       swapExactTokensforDataTokens(baseTokenAmountIn,
       amountInMax,
       newPath,
       to,
       refFees,
       refAddress,
       deadline
       );


    }

    
function swapExactDatatokensforTokens(
        uint amountDTIn,
        uint amountOutMax,
        address[] calldata path,
        address to,
        uint256 refFees,
        address refAddress,
        uint256 deadline
    )  _lock_ public 

    {
    // assuming the direct swap with the underlying base token (OCEAN/H20)
    uint256[3] tokenInOutMarket = [path[0], path[1], publishMarketAddress];
    uint256 minAmountOutBT = getAmountOutExactIn(path[0],path[1], amountDTIn, dtpool.getSwapFees());
    uint256 maxPrice = getSpotPrice(path[0], path[1],dtpool.getSwapFees());
    uint256[4] amountsInOutMaxFee = [amountDTIn, minAmountOutBT, maxPrice, dtpool.getSwapFees() ];
    // then swapping the datatokens with the balancer pool.
    uint256 swappedAmountBTOut = dtpool.swapExactAmountIn(
        tokenInOutMarket,
        amountsInOutMaxFee)[0];
    
    
    // converting the resulting amount after deduction of the collector fees 
    
    uint256 swappedFinalBT = swappedAmountBTOut - getSwapFees();
    
    // now we will be converting underlying baseToken to the destination token.

    address dtAddress = path[1];

    // first  new path will be the addresses of the intermediate LP tokens that will be swapped.
    uint256[] newPath ;
    for(int i = 1; i < path.length-1; i++)
    {
        newPath.push(path[i]);
    }
    
    adapter.swapExactTokenforTokens(
        swappedFinalBT,
        amountOutMax,
        newPath,
        to,
        deadline
    );
    collector.withdrawToken(dataToken); 
    }

}
