pragma solidity >=0.8.0 <0.9.0;

//Copyright of DataX Protocol contributors
//SPDX-License-Identifier: BSU-1.1

interface IPoolRouter {
    function swapDatatokenToExactBaseToken(
        address,
        address,
        address,
        address,
        uint256,
        uint256
    ) external returns (uint256, uint256);

    function swapExactDatatokenToBaseToken(
        address,
        address,
        address,
        address,
        uint256,
        uint256
    ) external returns (uint256);

    function swapBaseTokenToExactDatatoken(
        address,
        address,
        address,
        address,
        uint256,
        uint256
    ) external returns (uint256, uint256);

    function swapExactBaseTokenToDatatoken(
        address,
        address,
        address,
        address,
        uint256,
        uint256
    ) external returns (uint256);
}
