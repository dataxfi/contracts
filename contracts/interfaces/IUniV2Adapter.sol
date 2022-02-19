pragma solidity >=0.8.0 <0.9.0;

//SPDX-License-Identifier: BSU-1.1

interface IUniV2Adapter {
    function swapETHtoExactTokens(
        uint256 amountOut,
        address[] calldata path,
        uint256 deadline
    ) external payable returns (uint256 amountsOut);

    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256 amountsOut);

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256 amountsOut);

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256 amountsOut);
}
