pragma solidity >=0.8.0 <0.9.0;
//Copyright of DataX Protocol contributors
//SPDX-License-Identifier: BSU-1.1

import "../interfaces/IUniV2Adapter.sol";
import "../interfaces/ITradeRouter.sol";
import "../interfaces/ICommunityFeeCollector.sol";
import "../interfaces/ocean/IPool.sol";
import "../interfaces/ocean/IFactoryRouter.sol";
import "../interfaces/ocean/IFixedRateExchange.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract TradeRouter is ReentrancyGuard {
    using SafeMath for uint256;
    ICommunityFeeCollector collector;
    IStorage store;
    uint8 public version;
    uint256 private constant ZERO_FEES = 0;
    uint256 private constant MAX_INT = 2**256 - 1;
    uint256 private constant BASE = 1e18;

    event TradedETHToDataToken(
        address indexed tokenOut,
        address from,
        address to,
        uint256 amountOut
    );
    event TradedTokenToDataToken(
        address indexed tokenOut,
        address indexed tokenIn,
        address from,
        address to,
        uint256 amountOut
    );

    struct Fees {
        uint256 baseTokenAmount;
        uint256 oceanFeeAmount;
        uint256 publishMarketFeeAmount;
        uint256 consumeMarketFeeAmount;
    }

    struct TradeInfo {
        address[5] meta; //[source, dtAddress, to, refAddress, adapterAddress]
        uint256[3] uints; //[dtAmountOut/minDTAmountOut/tokenAmountOut/minTokenAmountOut, refFees, dtAmountIn/maxDTAmountIn/tokenAmountIn/maxTokenAmountIn]
        address[] path;
        bool isFRE;
        bytes32 exchangeId;
    }

    constructor(uint8 _version, address _storage) {
        version = _version;
        store = IStorage(_storage);
    }

    function swapETHToExactDatatoken(TradeInfo calldata info)
        external
        payable
        nonReentrant
        returns (uint256 amountOut)
    {
        require(
            info.meta[2] != address(0),
            "TradeRouter: Destination address not provided"
        );

        //TODO: deduct trade fee + ref fee
        IUniV2Adapter adapter = IUniV2Adapter(info.meta[4]);
        IERC20 baseToken = IERC20(info.path[info.path.length - 1]);

        //swap quote token to dt
        if (info.isFRE) {
            //handle FRE swap
            IFixedRateExchange exchange = IFixedRateExchange(info.meta[0]);
            //calc base amount In
            (uint256 baseAmountOut, , , ) = exchange.calcBaseInGivenOutDT(
                info.exchangeId,
                info.uints[0],
                ZERO_FEES
            );
            //swap ETH to pool base token
            amountOut = adapter.swapETHForExactTokens{value: msg.value}(
                baseAmountOut,
                info.path,
                address(this),
                msg.sender
            );

            //approve Exchange to spend base token
            require(
                baseToken.approve(address(exchange), amountOut),
                "TradeRouter: Failed to approve Basetoken on FRE"
            );

            uint256 preBalance = baseToken.balanceOf(address(this));
            exchange.buyDT(
                info.exchangeId,
                info.uints[0],
                amountOut,
                address(0),
                ZERO_FEES
            );
            uint256 postBalance = baseToken.balanceOf(address(this));
            uint256 tokensToRefund = amountOut.sub(preBalance.sub(postBalance));

            if (tokensToRefund > 0) {
                //refund remaining base tokens
                require(
                    baseToken.transfer(info.meta[2], tokensToRefund),
                    "TradeRouter: Basetoken refund failed"
                );
            }
        } else {
            //handle Pool swap
            IPool pool = IPool(info.meta[0]);
            //calc base amountIn
            (uint256 baseAmountOut, , , , ) = pool.getAmountInExactOut(
                info.path[info.path.length - 1],
                info.meta[1],
                info.uints[0],
                ZERO_FEES
            );
            //swap ETH to dtpool quote token
            amountOut = adapter.swapETHForExactTokens{value: msg.value}(
                baseAmountOut,
                info.path,
                address(this),
                msg.sender
            );
            //approve Pool to spend base token
            require(
                baseToken.approve(address(pool), amountOut),
                "TradeRouter: Failed to approve Basetoken on Pool"
            );

            address[3] memory tokenInOutMarket = [
                info.path[info.path.length - 1],
                info.meta[1],
                address(0)
            ];
            uint256[4] memory amountsInOutMaxFee = [
                amountOut,
                info.uints[0],
                MAX_INT,
                ZERO_FEES
            ];
            (uint256 amountIn, ) = pool.swapExactAmountOut(
                tokenInOutMarket,
                amountsInOutMaxFee
            );

            //refund remaining base tokens
            uint256 tokensToRefund = amountOut.sub(amountIn);
            if (tokensToRefund > 0) {
                require(
                    baseToken.transfer(info.meta[2], tokensToRefund),
                    "TradeRouter: Basetoken refund failed"
                );
            }
        }

        //transfer dt to destination address
        require(
            IERC20(info.meta[1]).transfer(info.meta[2], info.uints[0]),
            "Error: DT transfer failed"
        );

        emit TradedETHToDataToken(
            info.meta[1],
            msg.sender,
            info.meta[2],
            info.uints[0]
        );
    }

    function swapTokenToExactDatatoken(TradeInfo calldata info)
        external
        payable
        nonReentrant
        returns (uint256 amountOut)
    {
        require(
            info.meta[2] != address(0),
            "TradeRouter: Destination address not provided"
        );

        //TODO: deduct trade fee + ref fee
        IUniV2Adapter adapter = IUniV2Adapter(info.meta[4]);
        IERC20 baseToken = IERC20(info.path[info.path.length - 1]);

        //swap quote token to dt
        if (info.isFRE) {
            //handle FRE swap
            IFixedRateExchange exchange = IFixedRateExchange(info.meta[0]);
            //calc base amount In
            (uint256 baseAmountOut, , , ) = exchange.calcBaseInGivenOutDT(
                info.exchangeId,
                info.uints[0],
                ZERO_FEES
            );
            //swap ETH to pool base token
            amountOut = adapter.swapTokensForExactTokens(
                baseAmountOut,
                info.uints[2],
                info.path,
                address(this),
                msg.sender
            );

            //approve Exchange to spend base token
            require(
                baseToken.approve(address(exchange), amountOut),
                "TradeRouter: Failed to approve Basetoken on FRE"
            );

            uint256 preBalance = baseToken.balanceOf(address(this));
            exchange.buyDT(
                info.exchangeId,
                info.uints[0],
                amountOut,
                address(0),
                ZERO_FEES
            );
            uint256 postBalance = baseToken.balanceOf(address(this));
            uint256 tokensToRefund = amountOut.sub(preBalance.sub(postBalance));

            if (tokensToRefund > 0) {
                //refund remaining base tokens
                require(
                    baseToken.transfer(info.meta[2], tokensToRefund),
                    "TradeRouter: Basetoken refund failed"
                );
            }
        } else {
            //handle Pool swap
            IPool pool = IPool(info.meta[0]);
            //calc base amountIn
            (uint256 baseAmountOut, , , , ) = pool.getAmountInExactOut(
                info.path[info.path.length - 1],
                info.meta[1],
                info.uints[0],
                ZERO_FEES
            );
            //swap ETH to dtpool quote token
            amountOut = adapter.swapTokensForExactTokens(
                baseAmountOut,
                info.uints[2],
                info.path,
                address(this),
                msg.sender
            );
            //approve Pool to spend base token
            require(
                baseToken.approve(address(pool), amountOut),
                "TradeRouter: Failed to approve Basetoken on Pool"
            );

            address[3] memory tokenInOutMarket = [
                info.path[info.path.length - 1],
                info.meta[1],
                address(0)
            ];
            uint256[4] memory amountsInOutMaxFee = [
                amountOut,
                info.uints[0],
                MAX_INT,
                ZERO_FEES
            ];
            (uint256 amountIn, ) = pool.swapExactAmountOut(
                tokenInOutMarket,
                amountsInOutMaxFee
            );

            //refund remaining base tokens
            uint256 tokensToRefund = amountOut.sub(amountIn);
            if (tokensToRefund > 0) {
                require(
                    baseToken.transfer(info.meta[2], tokensToRefund),
                    "TradeRouter: Basetoken refund failed"
                );
            }
        }

        //transfer dt to destination address
        require(
            IERC20(info.meta[1]).transfer(info.meta[2], info.uints[0]),
            "Error: DT transfer failed"
        );

        emit TradedTokenToDataToken(
            info.meta[1],
            info.path[0],
            msg.sender,
            info.meta[2],
            info.uints[2]
        );
    }

    function swapExactETHToDatatoken(TradeInfo calldata info)
        external
        payable
        nonReentrant
        returns (uint256 amountOut)
    {
        require(
            info.meta[2] != address(0),
            "TradeRouter: Destination address not provided"
        );

        IUniV2Adapter adapter = IUniV2Adapter(info.meta[4]);
        IERC20 baseToken = IERC20(info.path[info.path.length - 1]);

        //swap ETH to base token
        uint256[] memory amounts = adapter.getAmountsOut(msg.value, info.path);
        amountOut = adapter.swapExactETHForTokens{value: msg.value}(
            amounts[info.path.length - 1],
            info.path,
            address(this)
        );

        //swap quote token to DT
        if (info.isFRE) {
            //handle FRE swap
            IFixedRateExchange exchange = IFixedRateExchange(info.meta[0]);

            //calc base amount In
            (uint256 baseAmtPerDT, , , ) = exchange.calcBaseInGivenOutDT(
                info.exchangeId,
                BASE,
                ZERO_FEES
            );
            uint256 expectedDTAmt = amountOut.div(baseAmtPerDT);

            require(
                expectedDTAmt >= info.uints[0],
                "TradeRouter: Insufficient datatoken received"
            );
            require(
                baseToken.approve(address(exchange), amountOut),
                "TradeRouter: Failed to approve Basetoken on FRE"
            );
            exchange.buyDT(
                info.exchangeId,
                expectedDTAmt,
                amountOut,
                address(0),
                ZERO_FEES
            );

            //transfer DT to destination address
            require(
                IERC20(info.meta[1]).transfer(info.meta[2], expectedDTAmt),
                "Error: DT transfer failed"
            );
        } else {
            //handle Pool swap
            IPool pool = IPool(info.meta[0]);

            //approve Pool to spend base token
            require(
                baseToken.approve(address(pool), amountOut),
                "TradeRouter: Failed to approve Basetoken on Pool"
            );

            address[3] memory tokenInOutMarket = [
                info.path[info.path.length - 1],
                info.meta[1],
                address(0)
            ];
            uint256[4] memory amountsInOutMaxFee = [
                amountOut,
                info.uints[0],
                MAX_INT,
                ZERO_FEES
            ];
            (uint256 amtOut, ) = pool.swapExactAmountIn(
                tokenInOutMarket,
                amountsInOutMaxFee
            );

            //transfer DT to destination address
            require(
                IERC20(info.meta[1]).transfer(info.meta[2], amtOut),
                "Error: DT transfer failed"
            );
        }
        emit TradedETHToDataToken(
            info.meta[1],
            msg.sender,
            info.meta[2],
            info.uints[0]
        );
    }

    function calcDTOutGivenTokenIn(TradeInfo calldata info)
        public
        view
        returns (uint256 amountOut)
    {
        IUniV2Adapter adapter = IUniV2Adapter(info.meta[4]);
        uint256[] memory amounts = adapter.getAmountsOut(
            info.uints[2],
            info.path
        );
        IPool pool = IPool(info.meta[0]);
        (amountOut, , , , ) = pool.getAmountOutExactIn(
            info.path[info.path.length - 1],
            info.meta[1],
            amounts[amounts.length - 1],
            ZERO_FEES
        );
    }

    function calcTokenOutGivenDTIn(TradeInfo calldata info)
        public
        view
        returns (uint256 amountOut)
    {
        uint256 amountIn;
        if (info.isFRE) {
            IFixedRateExchange exchange = IFixedRateExchange(info.meta[0]);
            (amountIn, , , ) = exchange.calcBaseOutGivenInDT(
                info.exchangeId,
                info.uints[2],
                ZERO_FEES
            );
        } else {
            IPool pool = IPool(info.meta[0]);
            (amountIn, , , , ) = pool.getAmountInExactOut(
                info.meta[1],
                info.path[info.path.length - 1],
                info.uints[2],
                ZERO_FEES
            );
        }

        IUniV2Adapter adapter = IUniV2Adapter(info.meta[4]);
        uint256[] memory amountsOut = adapter.getAmountsOut(
            amountIn,
            info.path
        );
        amountOut = amountsOut[amountsOut.length - 1];
    }

    function calcDTInGivenTokenOut(TradeInfo calldata info)
        public
        view
        returns (uint256 amountIn)
    {
        IUniV2Adapter adapter = IUniV2Adapter(info.meta[4]);
        uint256[] memory amounts = adapter.getAmountsIn(
            info.uints[0],
            info.path
        );
        if (info.isFRE) {
            IFixedRateExchange fre = IFixedRateExchange(info.meta[0]);
            //TODO this.getDTIn(fre, info.exchangeId, )
        } else {
            IPool pool = IPool(info.meta[0]);
            (amountIn, , , , ) = pool.getAmountInExactOut(
                info.meta[1],
                info.path[info.path.length - 1],
                amounts[amounts.length - 1],
                ZERO_FEES
            );
        }
    }

    function calcTokenInGivenDTOut(TradeInfo calldata info)
        public
        view
        returns (uint256 amountIn)
    {
        uint256 amountOut;
        if (info.isFRE) {
            IFixedRateExchange fre = IFixedRateExchange(info.meta[0]);
            (amountOut, , , ) = fre.calcBaseInGivenOutDT(
                info.exchangeId,
                info.uints[2],
                ZERO_FEES
            );
        } else {
            IPool pool = IPool(info.meta[0]);
            (amountOut, , , , ) = pool.getAmountInExactOut(
                info.path[info.path.length - 1],
                info.meta[1],
                info.uints[2],
                ZERO_FEES
            );
        }

        IUniV2Adapter adapter = IUniV2Adapter(info.meta[4]);
        uint256[] memory amountsIn = adapter.getAmountsIn(amountOut, info.path);
        amountIn = amountsIn[0];
    }

    function getFREBaseRate(
        IFixedRateExchange exchange,
        bytes32 exchangeId,
        uint256 opcFees
    )
        public
        view
        returns (
            uint256 baseRate,
            uint256 basefees,
            uint256 fees
        )
    {
        uint256 rate = exchange.getRate(exchangeId);
        basefees = opcFees.div(BASE);
        fees = rate.mul(basefees);
        baseRate = rate.add(fees);
    }

    function getDTIn(
        IFixedRateExchange fre,
        bytes32 exchangeId,
        uint256 baseTokenOutAmount
    ) public view returns (uint256 datatokenAmount) {
        (
            uint256 dtDecimals,
            uint256 btDecimals,
            uint256 fixedRate
        ) = getExchangeVars(fre, exchangeId);

        uint256 datatokenAmountBeforeFee = baseTokenOutAmount
            .mul(BASE)
            .mul(10**dtDecimals)
            .div(10**btDecimals)
            .div(fixedRate);

        Fees memory fee = Fees(0, 0, 0, 0);
        (uint256 marketFee, , uint256 opcFee, , ) = fre.getFeesInfo(exchangeId);
        if (opcFee != 0) {
            fee.oceanFeeAmount = datatokenAmountBeforeFee.mul(opcFee).div(BASE);
        } else fee.oceanFeeAmount = 0;

        if (marketFee != 0) {
            fee.publishMarketFeeAmount = datatokenAmountBeforeFee
                .mul(marketFee)
                .div(BASE);
        } else {
            fee.publishMarketFeeAmount = 0;
        }

        datatokenAmount = datatokenAmountBeforeFee
            .add(fee.publishMarketFeeAmount)
            .add(fee.oceanFeeAmount)
            .add(fee.consumeMarketFeeAmount);
    }

    function getExchangeVars(IFixedRateExchange fre, bytes32 exchangeId)
        private
        view
        returns (
            uint256 dtDecimals,
            uint256 btDecimals,
            uint256 fixedRate
        )
    {
        (, , dtDecimals, , btDecimals, fixedRate, , , , , , ) = fre.getExchange(
            exchangeId
        );
    }

    //receive ETH
    receive() external payable {}
}
