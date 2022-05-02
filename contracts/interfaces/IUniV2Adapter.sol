pragma solidity >=0.8.0 <0.9.0;

//SPDX-License-Identifier: BSU-1.1

interface IUniV2Adapter {
    /**
     *@dev swaps ETH to Exact  DT amounts
     *amountOut  is the exact tokens (DT) that you want .
     *path  are the array of  token address whose duration is followed for liquidity
     *to destination address for output tokens
     *refundTo destination address for remaining token refund
     */
    function swapETHForExactTokens(
        uint256 amountOut,
        address[] calldata path,
        address to,
        address refundTo
    ) external payable returns (uint256[2] memory amountsOut);

    /** @dev swaps Exact ETH to Tokens (as DT in tradeRouter).
     * amountOutMin minimum output amount
     * path array of address of tokens used for swapping.
     * to destination address for output tokens
     */

    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to
    ) external payable returns (uint256[2] memory amountsOut);

    /** @dev swaps Exact Tokens (DT) for WETH
     * amountIn exact token input amount
     * amountOutMin minimum expected output amount
     * path path of tokens
     * to destination address for output tokens
     */

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to
    ) external payable returns (uint256 amountsOut);

    /** @dev swaps Exact Tokens (DT/ERC20) for Tokens(DT/ERC20) ,
     * amountIn exact token input amount
     * amountOutMin minimum expected output amount
     * path path of tokens
     * to destination address for output tokens
     */
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to
    ) external returns (uint256 amountOut);

    /** @dev swaps Tokens (DT / ERC20) for Exact tokens  (DT / ERC20)
     * amountOut expected output amount
     * amountInMax maximum input amount
     * path path of tokens
     * to destination address for output tokens
     * refundTo destination address for remaining token refund
     */

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        address refundTo
    ) external returns (uint256[] memory amountsOut);

    function getAmountsOut(uint256 amountIn, address[] memory path)
        external
        view
        returns (uint256[] memory amounts);

    function getAmountsIn(uint256 amountOut, address[] memory path)
        external
        view
        returns (uint256[] memory amounts);
}
