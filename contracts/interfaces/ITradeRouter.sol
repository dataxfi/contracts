pragma solidity >=0.8.0 <0.9.0;

//SPDX-License-Identifier: BSU-1.1

struct TradeInfo {
    address[5] meta; //[source, dtAddress, to, refAddress, adapterAddress]
    uint256[4] uints; //[exactAmountIn/maxAmountIn, baseAmountNeeded, exactAmountOut/minAmountOut, refFees]
    address[] path;
    bool isFRE;
    bytes32 exchangeId;
}

/** @notice : interface to swap between erc20 tokens and datatokens
 */
interface ITradeRouter {
    /********* ETH <-> DT ************/

    /** @dev Swaps given max amount of ETH (native token) to datatokens
     */
    function swapETHToExactDatatoken(TradeInfo calldata info)
        external
        payable
        returns (uint256 amountOut);

    /** @dev Swaps exact amount of ETH (native token) to datatokens
     */
    function swapExactETHToDataToken(TradeInfo calldata info)
        external
        returns (uint256 amountOut);

    /** @dev Swaps exact amount of datatokens to ETH (native token)
     */
    function swapExactDatatokensforETH(TradeInfo calldata info)
        external
        returns (uint256 amountOut);

    /** @dev Swaps given amount of datatokens to exact amount of  ETH (native token)
     */
    function swapDatatokentoExactETH(TradeInfo calldata info)
        external
        returns (uint256[] memory amounts);

    /********* ERC20 <-> DT ************/

    /** @dev Swaps given max amount of erc20 tokens to datatokens
     */
    function swapTokentoExactDatatoken(TradeInfo calldata info)
        external
        returns (uint256[] memory amounts);

    /** @dev Swaps exact amount of erc20 tokens to datatokens
     */
    function swapExactTokenToDataToken(TradeInfo calldata info)
        external
        returns (uint256[] memory amounts);

    /** @dev Swaps Exact amount of datatokens to max amount of  datatokens
     */
    function swapExactDatatokentoToken(TradeInfo calldata info)
        external
        returns (uint256[] memory amounts);

    /** @dev Swaps given amount of datatokens to exact amount of  erc20 tokens
     */
    function swapDatatokentoExactToken(TradeInfo calldata info)
        external
        returns (uint256[] memory amounts);

    /********* DT <-> DT ************/

    /** @dev Swaps exact amount of datatokens to erc20 tokens
     */
    function swapExactDatatokenToDatatoken(TradeInfo calldata info)
        external
        returns (uint256[] memory amounts);

    /** @dev Swaps given max amount of datatokens to exact datatokens
     */
    function swapDatatokentoExactDatatoken(TradeInfo calldata info)
        external
        returns (uint256[] memory amounts);
}
