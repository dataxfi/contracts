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
contract TradeRouter is Base , ICommunityFeeCollector,IUniswapV2Adapter{
    using SafeMath for uint256;
    IUniV2Adapter adapter;
    ICommunityFeeCollector collector;
    uint256 public communityFee;
    uint public currentVersionTR;
    constructor(address adapterAddress , address dtpoolAddress , uint _version , uint _fees,address  _StorageAddress, address _collectorAddress ) {
        adapter = IUniV2Adapter(adapterAddress);
        IBPool dtpool = IBPool(dtPoolAddress);
        IStorage reg = IStorage(_StorageAddress);
        collector = ICommunityFeeCollector(_collectorAddress);
        currentVersion = _version;
        setCommunityFees(_fees);
        }
    modifier onlyGov {
        require(msg.sender == Owner());
    }
    
    
// getter function returning the community fees for the current state of the contracts.
    function getCommunityFees() public returns (uint256) {
        return(communityFee);
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
    function setVersionInStorage() public onlyGov {
        return reg.upgradeContractAddresses(keccak256("versionTR", currentVersionTR),address(this));
    }

    /** @dev allows the swap between ETH to data token 
     @dev here we will follow tokens --> exact tokens --> exact DT , just the difference is for the ETH we have the different function
    // @Param amountsOut = ["TokenInput", "0" ,getOutputAmounts() ]
    // and given the path is addr["WETH","OceanAddr","DTAddress"]. */
    function swapETHToExactDatatoken(
        address dtPoolAddress,
        uint256[] calldata amountsOut,
        address[] calldata path,
        address datatoken,
        uint256 deadline
    ) external __lock__ payable {
        // convert ETH to Ocean
        uint256 amountsOcean = adapter.swapETHtoExactTokens(
            amountsOut[0],
            path,
            deadline
        );
        // convert Ocean to Datatokens 
        // indexing will be from 0
        address oceanToken = path[path.length - 1];
        // to be send to the feeCollector and the rest is to be converted 
         uint256 feesCollector = mul(amountsOcean, getCommunityFees());
        uint256 OceanAmountSwapped =  sub(amountsOcean, feesCollector);

        IERC20(oceanToken).safeTransferFrom(oceanToken, address(this),  feesCollector);
        // and then finally staking to the data token
        dtpool.swapExactAmountOut(
            oceanToken,
            OceanAmountSwapped,
            datatoken,
            amountsOut[1],
            0 //maxPrice
        );
    }


    //TODO : function swap ERC20 to exact DT
    function swapTokenToExactDatatoken(
        address dtpoolAddress
        uint256[] calldata amountsOut,
        address[] calldata path,
        address datatoken,
        uint256 deadline
    ) external  __lock__ payable{
    
    
       uint256 amounts = adapter.swapExactTokensForTokens(AmountIn, amountOutMin, path, to, deadline);
       address oceanToken = path[path.length - 1];
        dtpool.swapExactAmountIn(
            oceanToken,
            amounts,
            datatoken,
            amountsOut[1],
            0 //maxPrice
        );

    }

    function swapDatatokenforDataToken(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address datatoken,
        uint256 deadline
    ) external {
        // swap exact token to token and then using the pool.
        uint256 ExactAmountsOutOcean = adapter.swapTokensForExactTokens(amountOut,amountInMax, path,to , deadline);
               address oceanToken = path[path.length - 1];

        // and then as previously , but that we will 

        dtpool.swapExactAmountIn(
                oceanToken,
                ExactAmountsOutOcean,
                datatoken,
                0);
    }

    //TODO : function swap DT to exact ERC20
    function swapDatatokenToExactToken(
        address datatoken,
        address maxAmountIn,
        address[] calldata path,
        uint256 deadline

    ) external {
        // flow : DT unstaked --> oceanToken --> ExactTokens 
        address erc20tokenOut = path[path.length - 1];
        swap.swapExactAmountOut(datatoken, maxAmountIn,erc20tokenOut, deadline);
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
       // swapDatatokenForExactTokens();
       // swapExactTokenstoDataToken();


    }







}
