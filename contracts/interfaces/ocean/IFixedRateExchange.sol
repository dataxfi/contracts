pragma solidity >=0.8.0 <0.9.0;

//Copyright of DataX Protocol contributors
//SPDX-License-Identifier: BSU-1.1

interface IFixedRateExchange {
    struct Exchange {
        bool active;
        address exchangeOwner;
        address datatoken;
        address baseToken;
        uint256 fixedRate;
        uint256 dtDecimals;
        uint256 btDecimals;
        uint256 dtBalance;
        uint256 btBalance;
        uint256 marketFee;
        uint256 oceanFeeAvailable;
        bool withMint;
    }

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

    function getRate(bytes32 exchangeId) external view returns (uint256);

    function getAllowedSwapper(bytes32 exchangeId)
        external
        view
        returns (address);

    function getFeesInfo(bytes32 exchangeId)
        external
        view
        returns (
            uint256 marketFee,
            address marketFeeCollector,
            uint256 opcFee,
            uint256 marketFeeAvailable,
            uint256 oceanFeeAvailable
        );

    function getExchange(bytes32 exchangeId)
        external
        view
        returns (
            address exchangeOwner,
            address datatoken,
            uint256 dtDecimals,
            address baseToken,
            uint256 btDecimals,
            uint256 fixedRate,
            bool active,
            uint256 dtSupply,
            uint256 btSupply,
            uint256 dtBalance,
            uint256 btBalance,
            bool withMint
        );
}
