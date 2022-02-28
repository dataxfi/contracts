pragma solidity >=0.8.0 <0.9.0;
//SPDX-License-Identifier: BSU-1.1

import "../interfaces/IStorage.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/ownable.sol";

contract UniV2Adapter is IStorage {
    IUniswapV2Router02 public uniswapRouter;
    using SafeERC20 for ERC20;
    uint256 currentVersion;

    constructor(
        address _routerAddress,
        uint256 _currentVersion,
        uint256 _StorageAddress
    ) {
        uniswapRouter = IUniswapV2Router02(_routerAddress);
        IStorage reg = IStorage(_StorageAddress);
        currentVersion = _currentVersion;
    }

    modifier availableAmt(uint256 amountOut) {
        require(msg.value > amountOut, "balance-insufficient");
    }

    function setVersionInStorage() onlyOwner {
        return
            reg.upgradeContractAddresses(
                keccak256("currentVersionAdapter", currentVersion),
                address(this)
            );
    }

    /** @dev swaps ETH to Exact Ocean
     * oceanAmount
     * path
     * deadline
     */
    function swapETHtoExactTokens(
        uint256 amountOut,
        address[] calldata path,
        uint256 deadline
    )
        external
        payable
        availableAmt(amountOut)
        returns (uint256 memory amountsOut)
    {
        // using the uniswap router contract.
        amountsOut = uniswapRouter.swapETHForExactTokens{value: msg.value}(
            amountOut,
            path,
            msg.sender,
            deadline
        );
        require(
            token.transfer(msg.sender, address(this).balance),
            "Error: ETH Refund Failed"
        );
    }

    /** @dev swaps Exact ETH to Tokens (OCEAN/H2O)
     * amountOutMin minimum output amount
     * path path of tokens
     * to destination address for output tokens
     * deadline transaction deadline
     */
    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    )
        external
        payable
        availableAmt(amountOutMin)
        returns (uint256 memory amountsOut)
    {
        // calling external router for the swap
        amountsOut = uniswapRouter.swapExactETHForTokens{value: msg.value}(
            amountOutMin,
            path,
            msg.sender,
            deadline
        );

        require(
            token.transfer(msg.sender, address(this).balance),
            "Error: ETH Refund Failed"
        );
    }

    /** @dev swaps Tokens (OCEAN/H2O) for Exact ETH
     * amountOut expected output amount
     * amountInMax maximum input amount
     * path path of tokens
     * to destination address for output tokens
     * deadline transaction deadline
     */
    function swapTokensForExactETH(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    )
        external
        payable
        availableAmt(amountOut)
        returns (uint256 memory amountsOut)
    {
        // only calling the given function given it implements the ETH transfer within the logic
        amountsOut = uniswapRouter.swapTokensForExactETH(
            amountOut,
            amountInMax,
            path,
            msg.sender,
            deadline
        );
    }

    /** @dev swaps Exact Tokens (OCEAN/H2O) for ETH
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
    )
        external
        payable
        availableAmt(amountIn)
        returns (uint256 memory amountsOut)
    {
        amountsOut = uniswapRouter.swapExactTokensForETH(
            amountIn,
            amountOutMin,
            path,
            to,
            deadline
        );
    }

    /** @dev swaps Exact Tokens (OCEAN/H2O) for Tokens(OCEAN/H2O)
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
    ) external returns (uint256 memory amountsOut) {
        amountsOut = uniswapRouter.swapExactTokensForTokens(
            amountIn,
            amountOutMin,
            path,
            msg.sender,
            deadline
        );

        require(
            token.transfer(msg.sender, address(this).balance),
            "Error: token refund failed/check-txn"
        );
    }

    /** @dev swaps Tokens (OCEAN/H2O) for Exact (OCEAN/H2O)
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
    ) external returns (uint256 memory amountsOut) {
        amountsOut = uniswapRouter.swapTokensForExactTokens(
            amountOut,
            amountInMax,
            path,
            msg.sender,
            deadline
        );
        require(
            token.transfer(msg.sender, address(this).balance),
            "Error: token refund failed/check-txn"
        );
    }

    receive() external payable {}
}
