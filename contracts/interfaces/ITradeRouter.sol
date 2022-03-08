pragma solidity ^0.8.9;


interface ITradeRouter {
/* @dev  get current version  number for the contract
*/
function getCurrentVersion() external view returns(uint);
/* @dev  get the constant fees being transferred to the controller after the  swap.
*/
function getSwapFees() external view returns(uint256);
/* @dev sets the new address for withdrawing the remaining tokens after swap and transfer to the user.
@param _feeCollector new address of wallet for getting fees in native token.
*/
function setCollector(address payable _feeCollector) external ;

/* set the parameter for arbitrary uint parameters (version , controller fees ...) for the functions in the contract.
@param variable_name  will be the  name of the  contract parameters that you want to store.  the accepted values for now : "swapFees", "Version"
@param value  the value corresponding to the parameter that you want to set.
*/
function setParameterUint(string memory variable_name ,  uint256 value) external;
/* swaps the  ETH from the caller function to dataTokens and transfers back  the user minus the swap fee (to collector)
@param amountOut fixed number of data tokens you want ot be swapped
@param path array of  addresses defining the liquidity path taken for swapping.
@param dstAddress is the destination address (user primarily) for getting the destination token .
@param deadline is the time in sec during the time AMM functions search for the corresponding orders to fill the order.(generally kept 30 to 60 max) 
*/
function swapETHforExactDataToken( uint  amountOut,  address[] calldata path, address dstAddress,  uint deadline)  external;
/* swaps the given amount of ETH denominated to be converted to the data token 
@param amountOutMin is the min amount of the exact DT  that are swapped before returning the remaining in case of deadline passed
@param path array of  addresses defining the liquidity path taken for swapping.
@param dstAddress is the destination address (user/third party contracts) for getting the destination token .
@param deadline is the time in sec during the time AMM functions search for the corresponding orders to fill the order.(generally kept 30 to 60 max) 

*/
function swapExactETHforDataToken( uint amountOutMin, address[] calldata path, address dstAddress, uint deadline) external;

/** swaps the exact Amount of input tokens  to given  data Token
@param amountIn exact amount of ERC20 that you want to swap 
@param amountOutMin min threashold swap amount result in order to get result.
@param path is the address array for the swap path based on liquidity.
@param dstAddress is the destination address (user/third party contracts) for getting the destination token .
@param deadline is the time in sec during the time AMM functions search for the corresponding orders to fill the order.(generally kept 30 to 60 max) 

 */
function swapExactTokensforDataToken( uint amountIn, uint amountOutMin,address[] calldata path, address to, uint deadline ) external;

/** swaps the exact Amount of data tokens  to arbitrary amount of data tokens defined by dynamic exchange ratio
@param amountIn exact amount of dataToken that you want to swap 
@param amountOutMin min threshold swap amount of DT before capitulation of deadline.
@param path is the address array for the swap path based on liquidity.
@param dstAddress is the destination address (user/third party contracts) for getting the destination token .
@param deadline is the time in sec during the time AMM functions search for the corresponding orders to fill the order.(generally kept 30 to 60 max) 

 */
function swapExactDataTokensforDataTokens (uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline) external;


/**swaps exact amount of dataTokens to the resulting amount of ETH tokens  


 */

function swapExactDataTokensforETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline) external;

/**
get exact amount of swapped dataToken given initial amount of another  dataToken.
 */



function swapDataTokenforExactDataToken( uint amountOut, uint amountInMax, address[] calldata path, address to,uint deadline) external;



}