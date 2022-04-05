pragma solidity >=0.8.0 <0.9.0;

//Copyright of DataX Protocol contributors
//SPDX-License-Identifier: BSU-1.1

interface IFixedRateExchange {
    function buyDT(
        bytes32 exchangeId,
        uint256 datatokenAmount,
        uint256 maxBaseTokenAmount,
        address consumeMarketAddress,
        uint256 consumeMarketSwapFeeAmount
    ) external;

    function sellDT(
        bytes32 exchangeId,
        uint256 datatokenAmount,
        uint256 minBaseTokenAmount,
        address consumeMarketAddress,
        uint256 consumeMarketSwapFeeAmount
    ) external;

    function calcBaseInGivenOutDT(
        bytes32 exchangeId,
        uint256 datatokenAmount,
        uint256 consumeMarketSwapFeeAmount
    )
        external
        view
        returns (
            uint256 baseTokenAmount,
            uint256 oceanFeeAmount,
            uint256 publishMarketFeeAmount,
            uint256 consumeMarketFeeAmount
        );

    function calcBaseOutGivenInDT(
        bytes32 exchangeId,
        uint256 datatokenAmount,
        uint256 consumeMarketSwapFeeAmount
    )
        external
        view
        returns (
            uint256 baseTokenAmount,
            uint256 oceanFeeAmount,
            uint256 publishMarketFeeAmount,
            uint256 consumeMarketFeeAmount
        );
}
