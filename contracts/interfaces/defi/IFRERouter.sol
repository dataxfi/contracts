pragma solidity >=0.8.0 <0.9.0;

//Copyright of DataX Protocol contributors
//SPDX-License-Identifier: BSU-1.1

interface IFRERouter {
    function swapExactDatatokenToBaseToken(
        address,
        address,
        address,
        address,
        bytes32,
        uint256,
        uint256
    ) external returns (uint256);

    function swapBaseTokenToExactDatatoken(
        address,
        address,
        address,
        bytes32,
        uint256,
        uint256
    ) external returns (uint256, uint256);

    function calcBaseTokenInGivenDatatokenOut(
        address,
        bytes32,
        uint256
    ) external view returns (uint256);

    function calcBaseTokenOutGivenDatatokenIn(
        address,
        bytes32,
        uint256
    ) external view returns (uint256);

    function calcDatatokenOutGivenBaseTokenIn(
        address,
        bytes32,
        uint256
    ) external view returns (uint256);

    function calcDatatokenInGivenBaseTokenOut(
        address,
        bytes32,
        uint256
    ) external view returns (uint256);
}
