pragma solidity >=0.8.0 <0.9.0;
//SPDX-License-Identifier: BSU-1.1

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

//import "../interfaces/IERC20.sol";
//import "../Base.sol";

// REF - https://github.com/Uniswap/v2-periphery/blob/master/contracts/UniswapV2Router02.sol
// REF - https://github.com/Uniswap/v2-periphery/blob/master/contracts/libraries/UniswapV2Library.sol
contract UniV2Adapter is Base {
    IUniswapV2Router02 public uniswapRouter;
    using SafeERC20 for ERC20;

    constructor(address _routerAddress, address _oceanAddress) {
        uniswapRouter = IUniswapV2Router02(_routerAddress);
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
    ) external payable returns (uint256 memory amountsOut) {
        require(msg.value > 0, "Error: No ETH for swap");
        amountsOut = uniswapRouter.swapETHForExactTokens{value: msg.value}(
            amountOut,
            path,
            msg.sender,
            deadline
        );

        // refund leftover ETH to user
        require(
            token.transfer(msg.sender, address(this).balance),
            "Error: ETH Refund Failed"
        );
    }

    /** @dev swaps Exact ETH to Ocean
     * oceanAmount
     * path
     * deadline
     */
    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256 memory amountsOut) {
        require(msg.value > 0, "Error: No ETH for swap");
        amountsOut = uniswapRouter.swapExactETHForTokens{value: msg.value}(
            amountOutMin,
            path,
            msg.sender,
            deadline
        );
    }

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
    }

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
    }

    /*function getEstimatedETHforDAI(uint256 daiAmount, address[] calldata path)
        public
        view
        returns (uint256[] memory)
    {
        return uniswapRouter.getAmountsIn(daiAmount, path);
    }*/

    // important to receive ETH
    receive() external payable {}
}
