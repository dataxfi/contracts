pragma solidity >=0.8.0 <0.9.0;

//SPDX-License-Identifier: BSU-1.1

/** @notice : interface to swap between erc20 tokens and datatokens
 */
interface ITradeRouter {
    /** @dev  get current version  number for the contract
     */
    function getCurrentVersion() external view returns (uint256);

    /** @dev  get the constant fees being transferred to the collector after the swap.
     */
    function getTradeFees() external view returns (uint256);

    /** @dev Swaps given max amount of ETH (native token) to datatokens
    @param amountOut is the exact amount of datatokens you want to be receive
    @param amountInMax is the max amount of ETH you want to spend
    @param path is the address array for the swap path based on liquidity
    @param to is the destination address for receiving destination token
    @param refFees is the referral fees paid to external dapps
    @param refAddress is the address where referral fees are paid to
    @param deadline is the max time in sec during which order must be filled
     */
    function swapETHforExactDatatokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 refFees,
        address refAddress,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    /** @dev Swaps exact amount of ETH (native token) to datatokens
    @param amountOutMin is the min amount of datatokens you want to receive
    @param path is the address array for the swap path based on liquidity
    @param to is the destination address for receiving destination token
    @param refFees is the referral fees paid to external dapps
    @param refAddress is address where referral fees are paid to
    @param deadline is the max time in sec during which order must be filled
     */
    function swapExactETHforDataTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 refFees,
        address refAddress,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    /** @dev Swaps exact amount of datatokens to ETH (native token)
    @param amountIn is the exact amount of datatokens you want to spend 
    @param amountOutMin is the min amount of ETH you want to receive
    @param path is the address array for the swap path based on liquidity
    @param to is the destination address for receiving destination token
    @param refFees is the referral fees paid to external dapps
    @param refAddress is address where referral fees are paid to
    @param deadline is the max time in sec during which order must be filled
     */
    function swapExactDatatokensforETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 refFees,
        address refAddress,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    /** @dev Swaps given max amount of erc20 tokens to datatokens
    @param amountOut is the exact amount of Datatokens you want to be receive
    @param amountInMax is the max amount of erc20 tokens you want to spend
    @param path is the address array for the swap path based on liquidity
    @param to is the destination address for receiving destination token
    @param refFees is the referral fees paid to external dapps
    @param refAddress is the address where referral fees are paid to
    @param deadline is the max time in sec during which order must be filled
     */
    function swapTokensforExactDatatokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 refFees,
        address refAddress,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    /** @dev Swaps exact amount of erc20 tokens to datatokens
    @param amountIn is the exact amount of erc20 tokens you want to spend 
    @param amountOutMin is the min amount of datatokens you want to receive
    @param path is the address array for the swap path based on liquidity
    @param to is the destination address for receiving destination token
    @param refFees is the referral fees paid to external dapps
    @param refAddress is address where referral fees are paid to
    @param deadline is the max time in sec during which order must be filled
     */
    function swapExactTokensforDataTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 refFees,
        address refAddress,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    /** @dev Swaps exact amount of datatokens to erc20 tokens
    @param amountIn is the exact amount of datatokens you want to spend 
    @param amountOutMin is the min amount of erc20 tokens you want to receive
    @param path is the address array for the swap path based on liquidity
    @param to is the destination address for receiving destination token
    @param refFees is the referral fees paid to external dapps
    @param refAddress is address where referral fees are paid to
    @param deadline is the max time in sec during which order must be filled
     */
    function swapExactDatatokensforDatatokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 refFees,
        address refAddress,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    /** @dev Swaps given max amount of datatokens to exact datatokens
    @param amountOut is the exact amount of datatokens you want to be receive
    @param amountInMax is the max amount of datatokens you want to spend
    @param path is the address array for the swap path based on liquidity
    @param to is the destination address for receiving destination token
    @param refFees is the referral fees paid to external dapps
    @param refAddress is the address where referral fees are paid to
    @param deadline is the max time in sec during which order must be filled
     */
    function swapDatatokensforExactDatatokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 refFees,
        address refAddress,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    /** @dev Swaps Exact amount of datatokens to max amount of  datatokens
    @param amountDTIn is the exact amount of datatokens you want to be swapped 
    @param amountOutMax is the max amount of datatokens you want to be swapped as result
    @param path is the address array for the swap path based on liquidity
    @param to is the destination address for the swapped tokens.
    @param refFees is the referral fees paid to external dapps.
    @param refAddress is the address where referral fees are paid to.
    @param deadline is the max time in sec during which order must be filled.
     */

    function swapExactDatatokensforTokens(
        uint256 amountDTIn,
        uint256 amountOutMax,
        address[] calldata path,
        address to,
        uint256 refFees,
        address refAddress,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}
