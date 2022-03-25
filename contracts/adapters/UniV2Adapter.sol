pragma solidity >=0.8.0 <0.9.0;
// Copyright DataX Protocol contributors
//SPDX-License-Identifier: BSU-1.1

import "../interfaces/IUniV2Router02.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract UniV2Adapter is ReentrancyGuard {
    IUniswapV2Router02 uniswapRouter;
    using SafeERC20 for ERC20;
    using SafeMath for uint256;
    uint256 public currentVersion;

    constructor(address _routerAddress, uint256 _currentVersion) {
        uniswapRouter = IUniswapV2Router02(_routerAddress);
        currentVersion = _currentVersion;
    }

    //check if this contract has needed spending allowance
    modifier hasAllowance(address tokenAddress, uint256 amount) {
        IERC20 token = IERC20(tokenAddress);
        uint256 _allowance = token.allowance(msg.sender, address(this));
        require(_allowance >= amount, "Error: Not enough allowance");
        _;
    }

    /** @dev swaps ETH to Exact Ocean
     * @param amountOut expected output amount
     * @param path path of tokens
     * @param to destination address for output tokens
     * @param deadline transaction deadline
     * @return amounts calculated for given path
     */
    function swapETHtoExactTokens(
        uint256 amountOut,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts) {
        //swap ETH to exact tokens
        amounts = uniswapRouter.swapETHForExactTokens{value: msg.value}(
            amountOut,
            path,
            to,
            deadline
        );

        //refund remaining ETH
        (bool refunded, ) = payable(to).call{value: msg.value.sub(amounts[0])}(
            ""
        );
        require(refunded, "Error: ETH refund failed");
    }

    /** @dev swaps Exact ETH to Tokens
     * @param amountOutMin minimum output amount
     * @param path path of tokens
     * @param to destination address for output tokens
     * @param deadline transaction deadline
     * @return amounts calculated for given path
     */
    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts) {
        amounts = uniswapRouter.swapExactETHForTokens{value: msg.value}(
            amountOutMin,
            path,
            to,
            deadline
        );
    }

    /** @dev swaps Tokens for Exact ETH
     * @param amountOut expected output amount
     * @param amountInMax maximum input amount
     * @param path path of tokens
     * @param to destination address for output tokens
     * @param deadline transaction deadline
     * @return amounts calculated for given path
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
        hasAllowance(path[0], amountInMax)
        returns (uint256[] memory amounts)
    {
        //approve Uni router to spend
        IERC20 token = IERC20(path[0]);
        require(
            token.transferFrom(msg.sender, address(this), amountInMax),
            "Error: Failed to self transfer"
        );
        require(
            token.approve(address(uniswapRouter), amountInMax),
            "Error: Failed to approve UniV2Router"
        );

        //swap tokens to exact ETH
        amounts = uniswapRouter.swapTokensForExactETH(
            amountOut,
            amountInMax,
            path,
            to,
            deadline
        );

        //refund remaining tokens
        require(
            token.transfer(msg.sender, amountInMax.sub(amounts[0])),
            "Error: Token refund failed"
        );
    }

    /** @dev swaps Exact Tokens for ETH
     * @param amountIn exact token input amount
     * @param amountOutMin minimum expected output amount
     * @param path path of tokens
     * @param to destination address for output tokens
     * @param deadline transaction deadline
     * @return amounts calculated for given path
     */
    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    )
        external
        hasAllowance(path[0], amountIn)
        returns (uint256[] memory amounts)
    {
        //approve Uni router to spend
        IERC20 token = IERC20(path[0]);
        require(
            token.transferFrom(msg.sender, address(this), amountIn),
            "Error: Failed to self transfer"
        );
        require(
            token.approve(address(uniswapRouter), amountIn),
            "Error: Failed to approve UniV2Router"
        );

        //swap exact tokens to ETH
        amounts = uniswapRouter.swapExactTokensForETH(
            amountIn,
            amountOutMin,
            path,
            to,
            deadline
        );
    }

    /** @dev swaps Exact Tokens for Tokens
     * @param amountIn exact token input amount
     * @param amountOutMin minimum expected output amount
     * @param path path of tokens
     * @param to destination address for output tokens
     * @param deadline transaction deadline
     * @return amounts calculated for given path
     */
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    )
        external
        hasAllowance(path[0], amountIn)
        returns (uint256[] memory amounts)
    {
        //approve Uni router to spend
        IERC20 token = IERC20(path[0]);
        require(
            token.transferFrom(msg.sender, address(this), amountIn),
            "Error: Failed to self transfer"
        );
        require(
            token.approve(address(uniswapRouter), amountIn),
            "Error: Failed to approve UniV2Router"
        );

        //swap exact tokens to tokens
        amounts = uniswapRouter.swapExactTokensForTokens(
            amountIn,
            amountOutMin,
            path,
            to,
            deadline
        );
    }

    /** @dev swaps Tokens for Exact Tokens
     * @param amountOut expected output amount
     * @param amountInMax maximum input amount
     * @param path path of tokens
     * @param to destination address for output tokens
     * @param deadline transaction deadline
     * @return amounts calculated for given path
     */
    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    )
        external
        hasAllowance(path[0], amountInMax)
        returns (uint256[] memory amounts)
    {
        //approve Uni router to spend
        IERC20 token = IERC20(path[0]);
        require(
            token.transferFrom(msg.sender, address(this), amountInMax),
            "Error: Failed to self transfer"
        );
        require(
            token.approve(address(uniswapRouter), amountInMax),
            "Error: Failed to approve UniV2Router"
        );

        // swap tokens to exact tokens
        amounts = uniswapRouter.swapTokensForExactTokens(
            amountOut,
            amountInMax,
            path,
            to,
            deadline
        );

        //refund remaining tokens
        require(
            token.transfer(msg.sender, amountInMax.sub(amounts[0])),
            "Error: Token refund failed"
        );
    }

    /** @dev calculates and returns output amounts for given input amount
     * @param amountIn exact input token amount
     * @param path of given tokens
     * @return amountsOut calculated for given path
     */
    function getAmountsOut(uint256 amountIn, address[] memory path)
        public
        view
        returns (uint256[] memory amountsOut)
    {
        amountsOut = uniswapRouter.getAmountsOut(amountIn, path);
    }

    /** @dev calculates and returns input amounts needed for expected output amount
     * @param amountOut exact expected output token amount
     * @param path of given tokens
     * @return amountsIn calculated for given path
     */
    function getAmountsIn(uint256 amountOut, address[] memory path)
        public
        view
        returns (uint256[] memory amountsIn)
    {
        amountsIn = uniswapRouter.getAmountsIn(amountOut, path);
    }

    receive() external payable {}
}
