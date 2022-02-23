pragma solidity >=0.8.0 <0.9.0;
//SPDX-License-Identifier: BSU-1.1
import "../Base.sol";
import "../interfaces/IUniV2Adapter.sol";
import "../interfaces/IBPool.sol";

contract TradeRouter is Base {
    IUniV2Adapter adapter;
    uint256 public communityFee;

    constructor(address adapterAddress) {
        adapter = IUniV2Adapter(adapterAddress);
    }

    function swapETHToExactDatatoken(
        address dtPoolAddress,
        uint256[] calldata amountsOut,
        address[] calldata path,
        address datatoken,
        uint256 deadline
    ) external payable {
        // convert ETH to Ocean
        uint256 amounts = adapter.swapETHtoExactTokens(
            amountsOut[0],
            path,
            deadline
        );
        // convert Ocean to Datatoken
        IBPool dtpool = IBPool(dtPoolAddress);
        address oceanToken = path[path.length - 1];

        dtpool.swapExactAmountOut(
            oceanToken,
            amounts,
            datatoken,
            amountsOut[1],
            0 //maxPrice
        );
    }

  

    //TODO : function swap ERC20 to exact DT
    function swapTokenToExactDatatoken(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external  payable{
        // conversion
        uint256 amounts = adapter.swapExactTokensForTokens(AmountIn, amountOutMin, path, to, deadline);
        // then converting the given ocean to dataToken


    }

    //TODO : function swap exact ERC20 To DT
    function swapExactTokenToDatatoken() external {}

    //TODO : function swap DT to exact ERC20
    function swapDatatokenToExactToken() external {}

    //TODO : function swap exact DT to ERC20
    function swapExactDatatokenToToken() external {}
}
