pragma solidity >=0.8.0 <0.9.0;
//SPDX-License-Identifier: BSU-1.1

import "../interfaces/IUniV2Router02.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract UniV2Adapter {
    IUniswapV2Router02 uniswapRouter;
    using SafeERC20 for ERC20;
    using SafeMath for uint256;
    uint256 public currentVersion;

    constructor(address _routerAddress, uint256 _currentVersion) {
        uniswapRouter = IUniswapV2Router02(_routerAddress);
        currentVersion = _currentVersion;
    }

    modifier hasAllowance(address tokenAddress, uint256 amount) {
        IERC20 token = IERC20(tokenAddress);
        uint256 _allowance = token.allowance(msg.sender, address(this));
        require(_allowance >= amount, "Error: Not enough allowance");
        _;
    }

    /** @dev swaps ETH to Exact Ocean
     * oceanAmount
     * path
     * deadline
     */
    function swapETHtoExactTokens(
        uint256 amountOut,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts) {
        amounts = uniswapRouter.swapETHForExactTokens{value: msg.value}(
            amountOut,
            path,
            to,
            deadline
        );

        (bool refunded, ) = payable(to).call{value: msg.value.sub(amounts[0])}(
            ""
        );
        require(refunded, "Error: ETH refund failed");
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

        amounts = uniswapRouter.swapTokensForExactETH(
            amountOut,
            amountInMax,
            path,
            to,
            deadline
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

        amounts = uniswapRouter.swapExactTokensForETH(
            amountIn,
            amountOutMin,
            path,
            to,
            deadline
        );
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

        amounts = uniswapRouter.swapExactTokensForTokens(
            amountIn,
            amountOutMin,
            path,
            to,
            deadline
        );
    }

    /** @dev swaps Tokens for Exact Tokens
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

        amounts = uniswapRouter.swapTokensForExactTokens(
            amountOut,
            amountInMax,
            path,
            to,
            deadline
        );
    }

    receive() external payable {}
}
