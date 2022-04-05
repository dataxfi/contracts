pragma solidity >=0.8.0 <0.9.0;
//Copyright of DataX Protocol contributors
//SPDX-License-Identifier: BSU-1.1

import "../interfaces/IUniV2Adapter.sol";
import "../interfaces/ITradeRouter.sol";
import "../interfaces/ICommunityFeeCollector.sol";
import "../interfaces/IPool.sol";
import "../interfaces/IFixedRateExchange.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract TradeRouter is ReentrancyGuard {
    using SafeMath for uint256;
    ICommunityFeeCollector collector;
    uint256 public currentVersion;
    uint256 ZERO_FEES = 0;
    uint256 MAX_INT = 2**256 - 1;

    constructor(uint256 _version) {
        currentVersion = _version;
    }

    function swapETHToExactDatatoken(
        uint256[4] calldata uints, //[quoteAmountOut, dtAmountOut, refFees, deadline]
        address[] calldata path,
        address[5] calldata meta, //[source, dtAddress, to, refAddress, adapterAddress]
        bool isFRE,
        bytes32 exchangeId
    ) external payable returns (uint256 amountIn) {
        require(meta[2] != address(0), "Destination address not provided");

        //TODO: deduct trade fee + ref fee

        //swap ETH to dtpool quote token
        IUniV2Adapter adapter = IUniV2Adapter(meta[4]);

        uint256[] memory _amounts = adapter.swapETHtoExactTokens{
            value: msg.value
        }(uints[0], path, address(this), uints[3]);

        IERC20 token = IERC20(path[path.length - 1]);

        //swap quote token to dt
        if (isFRE) {
            //handle FRE swap
            IFixedRateExchange exchange = IFixedRateExchange(meta[0]);

            //approve Exchange to spend base token
            require(
                token.approve(address(exchange), _amounts[_amounts.length - 1]),
                "Error: Failed to approve FRE"
            );

            exchange.buyDT(
                exchangeId,
                uints[1],
                _amounts[_amounts.length - 1],
                address(0),
                0
            );

            //transfer dt to destination address
            require(
                IERC20(meta[1]).transfer(meta[2], uints[1]),
                "Error: DT transfer failed"
            );
        } else {
            //handle Pool swap
            IPool pool = IPool(meta[0]);

            //approve Pool to spend base token
            require(
                token.approve(address(pool), _amounts[_amounts.length - 1]),
                "Error: Failed to approve Pool"
            );

            address[3] memory tokenInOutMarket = [
                path[path.length - 1],
                meta[1],
                address(0)
            ];
            uint256[4] memory amountsInOutMaxFee = [
                _amounts[_amounts.length - 1],
                uints[1],
                MAX_INT,
                ZERO_FEES
            ];
            (amountIn, ) = pool.swapExactAmountOut(
                tokenInOutMarket,
                amountsInOutMaxFee
            );

            //transfer dt to destination address
            require(
                IERC20(meta[1]).transfer(meta[2], uints[1]),
                "Error: DT transfer failed"
            );
        }
    }

    function swapExactETHToDatatoken(
        uint256[4] calldata uints, //[quoteAmountOut, dtAmountOut, refFees, deadline]
        address[] calldata path,
        address[5] calldata meta, //[source, dtAddress, to, refAddress, adapterAddress]
        bool isFRE,
        bytes32 exchangeId
    ) external payable returns (uint256 amountIn) {
        require(meta[2] != address(0), "Destination address not provided");

        //TODO: deduct trade fee + ref fee

        //swap ETH to dtpool quote token
        IUniV2Adapter adapter = IUniV2Adapter(meta[4]);

        uint256[] memory _amounts = adapter.swapExactETHForTokens{
            value: msg.value
        }(uints[0], path, address(this), uints[3]);

        IERC20 token = IERC20(path[path.length - 1]);

        //swap quote token to dt
        if (isFRE) {
            //handle FRE swap
            IFixedRateExchange exchange = IFixedRateExchange(meta[0]);

            //approve Exchange to spend base token
            require(
                token.approve(address(exchange), _amounts[_amounts.length - 1]),
                "Error: Failed to approve FRE"
            );

            exchange.buyDT(
                exchangeId,
                uints[1],
                _amounts[_amounts.length - 1],
                address(0),
                0
            );

            //transfer dt to destination address
            require(
                IERC20(meta[1]).transfer(meta[2], uints[1]),
                "Error: DT transfer failed"
            );
        } else {
            //handle Pool swap
            IPool pool = IPool(meta[0]);

            //approve Pool to spend base token
            require(
                token.approve(address(pool), _amounts[_amounts.length - 1]),
                "Error: Failed to approve Pool"
            );

            address[3] memory tokenInOutMarket = [
                path[path.length - 1],
                meta[1],
                address(0)
            ];
            uint256[4] memory amountsInOutMaxFee = [
                _amounts[_amounts.length - 1],
                uints[1],
                MAX_INT,
                ZERO_FEES
            ];
            (amountIn, ) = pool.swapExactAmountOut(
                tokenInOutMarket,
                amountsInOutMaxFee
            );

            //transfer dt to destination address
            require(
                IERC20(meta[1]).transfer(meta[2], uints[1]),
                "Error: DT transfer failed"
            );
        }
    }

    function swapExactDatatokenToETH(
        uint256[4] calldata uints, //[quoteAmountOut, dtAmountIn, refFees, deadline]
        address[] calldata path,
        address[5] calldata meta, //[source, dtAddress, to, refAddress, adapterAddress]
        bool isFRE,
        bytes32 exchangeId
    ) external payable returns (uint256 amountIn) {
        require(meta[2] != address(0), "Destination address not provided");

        IERC20 token = IERC20(path[path.length - 1]);

        //swap dt to base token
        if (isFRE) {
            //handle FRE swap
            IFixedRateExchange exchange = IFixedRateExchange(meta[0]);

            //approve Exchange to spend base token
            require(
                token.approve(address(exchange), uints[1]),
                "Error: Failed to approve FRE"
            );

            exchange.sellDT(exchangeId, uints[1], uints[0], address(0), 0);

            //transfer dt to destination address
            require(
                IERC20(meta[1]).transfer(meta[2], uints[1]),
                "Error: DT transfer failed"
            );
        } else {
            //handle Pool swap
            IPool pool = IPool(meta[0]);

            //approve Pool to spend base token
            require(
                token.approve(address(pool), uints[1]),
                "Error: Failed to approve Pool"
            );

            address[3] memory tokenInOutMarket = [meta[1], path[0], address(0)];
            uint256[4] memory amountsInOutMaxFee = [
                uints[0],
                uints[1],
                MAX_INT,
                ZERO_FEES
            ];
            (amountIn, ) = pool.swapExactAmountOut(
                tokenInOutMarket,
                amountsInOutMaxFee
            );

            //swap Dt to base token
            IUniV2Adapter adapter = IUniV2Adapter(meta[4]);

            uint256 amountOut = adapter.swapExactTokensForETH(
                uints[0],
                uints[0],
                path,
                address(this),
                uints[3]
            );

            //refund remaining ETH
            (bool refunded, ) = payable(meta[1]).call{value: amountOut}("");
            require(refunded, "Error: ETH refund failed");
        }
    }

    //receive ETH
    receive() external payable {}
}
