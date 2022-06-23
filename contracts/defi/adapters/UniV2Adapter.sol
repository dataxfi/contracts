pragma solidity >=0.8.0 <0.9.0;
// Copyright DataX Protocol contributors
//SPDX-License-Identifier: BSU-1.1

import "../../interfaces/defi/IUniV2Router02.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "hardhat/console.sol";

contract UniV2Adapter {
    IUniswapV2Router02 uniswapRouter;
    using SafeERC20 for ERC20;
    using SafeMath for uint256;
    uint256 public version;
    uint256 private constant DEADLINE = 600; //10 mins

    event Swapped(address[] path, uint256 amountOut);

    constructor(address _routerAddress, uint256 _version) {
        uniswapRouter = IUniswapV2Router02(_routerAddress);
        version = _version;
    }

    //check if this contract has needed spending allowance
    modifier hasAllowance(address tokenAddress, uint256 amount) {
        IERC20 token = IERC20(tokenAddress);
        uint256 _allowance = token.allowance(msg.sender, address(this));
        require(_allowance >= amount, "UniV2Adapter: Not enough allowance");
        _;
    }

    /** @dev swaps ETH to Exact Ocean
     * oceanAmount
     * path
     * deadline
     */
    function swapETHForExactTokens(
        uint256 amountOut,
        address[] calldata path,
        address to,
        address refundTo
    ) external payable returns (uint256 tokenAmountOut, uint256 refund) {
        //swap ETH to exact tokens
        uint256[] memory amounts = uniswapRouter.swapETHForExactTokens{
            value: msg.value
        }(amountOut, path, to, block.timestamp + DEADLINE);

        //output token amount
        tokenAmountOut = amounts[amounts.length - 1];
        refund = msg.value.sub(amounts[0]);

        //refund remaining ETH
        (bool refunded, ) = payable(refundTo).call{value: refund}("");
        require(refunded, "UniV2Adapter: ETH refund failed");

        emit Swapped(path, tokenAmountOut);
    }

    /** @dev swaps Exact ETH to Tokens
     * amountOutMin minimum output amount
     * path path of tokens
     * to destination address for output tokens
     * deadline transaction deadline
     */
    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to
    ) external payable returns (uint256 tokenAmountOut) {
        //swap exact ETH to tokens
        uint256[] memory amounts = uniswapRouter.swapExactETHForTokens{
            value: msg.value
        }(amountOutMin, path, to, block.timestamp + DEADLINE);
        //output token amount
        tokenAmountOut = amounts[amounts.length - 1];
        emit Swapped(path, tokenAmountOut);
    }

    /** @dev swaps Tokens for Exact ETH
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
        address refundTo
    )
        external
        payable
        hasAllowance(path[0], amountInMax)
        returns (uint256 tokenAmountIn, uint256 refund)
    {
        //approve Uni router to spend
        require(
            IERC20(path[0]).transferFrom(
                msg.sender,
                address(this),
                amountInMax
            ),
            "UniV2Adapter: Failed to self transfer"
        );
        require(
            IERC20(path[0]).approve(address(uniswapRouter), amountInMax),
            "UniV2Adapter: Failed to approve UniV2Router"
        );
        //swap tokens to exact ETH
        uint256[] memory amounts = uniswapRouter.swapTokensForExactETH(
            amountOut,
            amountInMax,
            path,
            to,
            block.timestamp + DEADLINE
        );

        tokenAmountIn = amounts[0];
        refund = amountInMax.sub(amounts[0]);

        //refund remaining tokens
        require(
            IERC20(path[0]).transfer(refundTo, refund),
            "UniV2Adapter: Token refund failed"
        );
    }

    /** @dev swaps Exact Tokens for ETH
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
        address to
    ) external hasAllowance(path[0], amountIn) returns (uint256 amtOut) {
        //approve Uni router to spend
        IERC20 token = IERC20(path[0]);
        require(
            token.transferFrom(msg.sender, address(this), amountIn),
            "UniV2Adapter: Failed to self transfer"
        );
        require(
            token.approve(address(uniswapRouter), amountIn),
            "UniV2Adapter: Failed to approve UniV2Router"
        );

        //swap exact tokens to ETH
        uint256[] memory amounts = uniswapRouter.swapExactTokensForETH(
            amountIn,
            amountOutMin,
            path,
            to,
            block.timestamp + DEADLINE
        );

        amtOut = amounts[amounts.length - 1];
    }

    /** @dev swaps Exact Tokens for Tokens
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
        address to
    ) external hasAllowance(path[0], amountIn) returns (uint256 amountOut) {
        //approve Uni router to spend
        IERC20 token = IERC20(path[0]);
        require(
            token.transferFrom(msg.sender, address(this), amountIn),
            "UniV2Adapter: Failed to self transfer"
        );
        require(
            token.approve(address(uniswapRouter), amountIn),
            "UniV2Adapter: Failed to approve UniV2Router"
        );

        //swap exact tokens to tokens
        uint256[] memory amounts = uniswapRouter.swapExactTokensForTokens(
            amountIn,
            amountOutMin,
            path,
            to,
            block.timestamp + DEADLINE
        );

        //output token amount
        amountOut = amounts[amounts.length - 1];
    }

    /** @dev swaps Tokens for Exact Tokens
     * amountOut expected output amount
     * amountInMax maximum input amount
     * path path of tokens
     * to destination address for output tokens
     * refundTo destination address for remaining token refund
     * deadline transaction deadline
     */
    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        address refundTo
    )
        external
        hasAllowance(path[0], amountInMax)
        returns (uint256 tokenAmountOut, uint256 refund)
    {
        //approve Uni router to spend
        require(
            IERC20(path[0]).transferFrom(
                msg.sender,
                address(this),
                amountInMax
            ),
            "UniV2Adapter: Failed to self transfer"
        );
        require(
            IERC20(path[0]).approve(address(uniswapRouter), amountInMax),
            "UniV2Adapter: Failed to approve UniV2Router"
        );

        // swap tokens to exact tokens
        uint256[] memory amounts = uniswapRouter.swapTokensForExactTokens(
            amountOut,
            amountInMax,
            path,
            to,
            block.timestamp + DEADLINE
        );
        tokenAmountOut = amounts[amounts.length - 1];
        refund = amountInMax.sub(amounts[0]);
        //refund remaining tokens
        require(
            IERC20(path[0]).transfer(refundTo, refund),
            "UniV2Adapter: Token refund failed"
        );
    }

    function getAmountsOut(uint256 amountIn, address[] memory path)
        public
        view
        returns (uint256[] memory amounts)
    {
        return uniswapRouter.getAmountsOut(amountIn, path);
    }

    function getAmountsIn(uint256 amountOut, address[] memory path)
        public
        view
        returns (uint256[] memory amounts)
    {
        return uniswapRouter.getAmountsIn(amountOut, path);
    }

    receive() external payable {}
}
