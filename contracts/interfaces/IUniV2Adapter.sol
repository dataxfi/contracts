pragma solidity >=0.8.0 <0.9.0;

//SPDX-License-Identifier: BSU-1.1

interface IUniV2Adapter {
/**set the  current  version of the contract in Storage lookup */
    function setVersionInStorage() external view ;


/** 
 *@dev swaps ETH to Exact  DT amounts  
 *@param amountOut  is the exact tokens (DT) that you want . 
 *@param path  are the array of  token address whose duration is followed for liquidity
 *@param  deadline is the transaction  deadline till then amountOut exact tokens are swapped .
 */
    function swapETHtoExactTokens(
        uint256 amountOut,
        address[] calldata path,
        uint256 deadline
    ) external payable returns (uint256 amountsOut);

/** @dev swaps Exact ETH to Tokens (as DT in tradeRouter).
  * amountOutMin minimum output amount
  * path array of address of tokens used for swapping.
  * to destination address for output tokens
  * deadline transaction deadline
  */

    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256 amountsOut);


    /** @dev swaps Exact Tokens (DT) for WETH
     * amountIn exact token input amount
     * amountOutMin minimum expected output amount
     * path path of tokens
     * to destination address for output tokens
     * deadline transaction deadline
     */



    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable
        returns (uint256  amountsOut);



 /** @dev swaps Exact Tokens (DT/ERC20) for Tokens(DT/ERC20) , 
     * amountIn exact token input amount
     * amountOutMin minimum expected output amount
     * path path of tokens
     * to destination address for output tokens
     * deadline transaction deadline
*/
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256 amountsOut);

    /** @dev swaps Tokens (DT / ERC20) for Exact tokens  (DT / ERC20)
     * amountOut expected output amount
     * amountInMax maximum input amount
     * path path of tokens
     * to destination address for output tokens
     * deadline transaction deadline
     */

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256 amountsOut);

}

