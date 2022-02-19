pragma solidity >=0.8.0 <0.9.0;

//SPDX-License-Identifier: BSU-1.1

interface IBPool {
    function initialize(
        address controller,
        address factory,
        uint256 swapFee,
        bool publicSwap,
        bool finalized
    ) external returns (bool);

    function setup(
        address dataTokenAaddress,
        uint256 dataTokenAmount,
        uint256 dataTokenWeight,
        address baseTokenAddress,
        uint256 baseTokenAmount,
        uint256 baseTokenWeight,
        uint256 swapFee
    ) external;

    function isFinalized() external view returns (bool);

    function isBound(address t) external view returns (bool);

    function getNumTokens() external view returns (uint256);

    function getCurrentTokens() external view returns (address[] memory tokens);

    function getFinalTokens() external view returns (address[] memory tokens);

    function getDenormalizedWeight(address token)
        external
        view
        returns (uint256);

    function getTotalDenormalizedWeight() external view returns (uint256);

    function getNormalizedWeight(address token) external view returns (uint256);

    function getBalance(address token) external view returns (uint256);

    function getSwapFee() external view returns (uint256);

    function getController() external view returns (address);

    function gulp(address token) external;

    function getSpotPrice(address tokenIn, address tokenOut)
        external
        view
        returns (uint256 spotPrice);

    function getSpotPriceSansFee(address tokenIn, address tokenOut)
        external
        view
        returns (uint256 spotPrice);

    function joinPool(uint256 poolAmountOut, uint256[] calldata maxAmountsIn)
        external;

    function exitPool(uint256 poolAmountIn, uint256[] calldata minAmountsOut)
        external;

    function swapExactAmountIn(
        address tokenIn,
        uint256 tokenAmountIn,
        address tokenOut,
        uint256 minAmountOut,
        uint256 maxPrice
    ) external;

    function swapExactAmountOut(
        address tokenIn,
        uint256 maxAmountIn,
        address tokenOut,
        uint256 tokenAmountOut,
        uint256 maxPrice
    ) external;

    function joinswapExternAmountIn(
        address tokenIn,
        uint256 tokenAmountIn,
        uint256 minPoolAmountOut
    ) external;

    function joinswapPoolAmountOut(
        address tokenIn,
        uint256 poolAmountOut,
        uint256 maxAmountIn
    ) external;

    function exitswapPoolAmountIn(
        address tokenOut,
        uint256 poolAmountIn,
        uint256 minAmountOut
    ) external;

    function exitswapExternAmountOut(
        address tokenOut,
        uint256 tokenAmountOut,
        uint256 maxPoolAmountIn
    ) external;
}
