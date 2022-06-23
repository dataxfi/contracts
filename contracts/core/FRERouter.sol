pragma solidity >=0.8.0 <0.9.0;
//Copyright of DataX Protocol contributors
//SPDX-License-Identifier: BSU-1.1

import "../interfaces/ocean/IFixedRateExchange.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../utils/Math.sol";
import "hardhat/console.sol";

contract FRERouter is ReentrancyGuard, Math {
    using SafeMath for uint256;
    uint8 public version;
    uint256 private constant ZERO_FEES = 0;
    uint256 private constant BASE = 1e18;

    struct Exchange {
        uint256 dtDecimals;
        uint256 btDecimals;
        uint256 fixedRate;
        uint256 marketFee;
        uint256 oceanFee;
    }

    constructor(uint8 _version) {
        version = _version;
    }

    // FRE : Exact DT to BT
    function swapExactDatatokenToBaseToken(
        address baseTokenAddress,
        address datatokenAddress,
        address to,
        address exchangeAddress,
        bytes32 exchangeId,
        uint256 dtAmountIn,
        uint256 minBaseAmountOut
    ) public returns (uint256 baseAmountOut) {
        IFixedRateExchange fre = IFixedRateExchange(exchangeAddress);
        require(
            fre.getAllowedSwapper(exchangeId) == address(this),
            "TradeRouter: Not an allowed Swapper"
        );
        IERC20 datatoken = IERC20(datatokenAddress);
        require(
            datatoken.balanceOf(msg.sender) >= dtAmountIn,
            "TradeRouter: Not enough Datatoken"
        );
        IERC20 baseToken = IERC20(baseTokenAddress);
        if (msg.sender != address(this)) {
            require(
                datatoken.transferFrom(msg.sender, address(this), dtAmountIn),
                "TradeRouter: Self-transfer Datatoken Failed"
            );
        }
        require(
            datatoken.approve(exchangeAddress, dtAmountIn),
            "TradeRouter: Failed to approve Basetoken on FRE"
        );
        uint256 preBal = baseToken.balanceOf(address(this)); //needed as sellDT() doesn't return DT needed
        fre.sellDT(
            exchangeId,
            dtAmountIn,
            minBaseAmountOut,
            address(0),
            ZERO_FEES
        );
        uint256 postBal = baseToken.balanceOf(address(this));
        baseAmountOut = postBal.sub(preBal);
        require(
            minBaseAmountOut <= baseAmountOut,
            "TradeRouter:  BaseAmount too low"
        );
        //send base tokens to beneficiary
        require(
            baseToken.transfer(to, baseAmountOut),
            "TradeRouter: Basetoken transfer failed"
        );
    }

    // FRE : BT to Exact DT
    function swapBaseTokenToExactDatatoken(
        address baseTokenAddress,
        address to,
        address exchangeAddress,
        bytes32 exchangeId,
        uint256 maxBaseAmountIn,
        uint256 dtAmountOut
    ) public returns (uint256 baseAmountIn, uint256 toRefund) {
        IFixedRateExchange fre = IFixedRateExchange(exchangeAddress);
        require(
            fre.getAllowedSwapper(exchangeId) == address(this),
            "TradeRouter: Not an allowed Swapper"
        );
        IERC20 baseToken = IERC20(baseTokenAddress);
        require(
            baseToken.balanceOf(msg.sender) >= maxBaseAmountIn,
            "TradeRouter: Not enough BaseToken"
        );
        if (msg.sender != address(this)) {
            require(
                baseToken.transferFrom(
                    msg.sender,
                    address(this),
                    maxBaseAmountIn
                ),
                "TradeRouter: Self-transfer Basetoken Failed"
            );
        }
        require(
            baseToken.approve(exchangeAddress, maxBaseAmountIn),
            "TradeRouter: Failed to approve Basetoken on FRE"
        );
        uint256 preBal = baseToken.balanceOf(address(this)); //needed as buyDT() doesn't return BT cost to buy DT
        fre.buyDT(
            exchangeId,
            dtAmountOut,
            maxBaseAmountIn,
            address(0),
            ZERO_FEES
        );
        uint256 postBal = baseToken.balanceOf(address(this));
        baseAmountIn = preBal.sub(postBal);
        toRefund = maxBaseAmountIn.sub(baseAmountIn);
        if (toRefund > 0) {
            //refund remaining base tokens
            require(
                baseToken.transfer(to, toRefund),
                "TradeRouter: Basetoken refund failed"
            );
        }
    }

    /********** Calculations *************/

    // FRE : Calc BT In Given DT Out
    function calcBaseTokenInGivenDatatokenOut(
        address exchange,
        bytes32 exchangeId,
        uint256 dtAmountOut
    ) public view returns (uint256 baseAmountIn) {
        IFixedRateExchange fre = IFixedRateExchange(exchange);
        (baseAmountIn, , , ) = fre.calcBaseInGivenOutDT(
            exchangeId,
            dtAmountOut,
            ZERO_FEES
        );
    }

    // FRE : Calc BT Out Given DT In
    function calcBaseTokenOutGivenDatatokenIn(
        address exchangeAddress,
        bytes32 exchangeId,
        uint256 dtAmountIn
    ) public view returns (uint256 baseAmountOut) {
        console.log("FRE Exchange ID ");
        console.logBytes32(exchangeId);
        IFixedRateExchange fre = IFixedRateExchange(exchangeAddress);
        (baseAmountOut, , , ) = fre.calcBaseOutGivenInDT(
            exchangeId,
            dtAmountIn,
            ZERO_FEES
        );
    }

    // FRE : Calc DT Out Given BT In
    function calcDatatokenOutGivenBaseTokenIn(
        address exchangeAddress,
        bytes32 exchangeId,
        uint256 baseAmountIn
    ) public view returns (uint256 dtAmountOut) {
        IFixedRateExchange fre = IFixedRateExchange(exchangeAddress);
        Exchange memory exchange;
        exchange.fixedRate = fre.getRate(exchangeId);
        (exchange.marketFee, , exchange.oceanFee, , ) = fre.getFeesInfo(
            exchangeId
        );

        uint256 dtAmountOutSansFee = baseAmountIn
            .mul(BONE)
            .mul(10**exchange.dtDecimals)
            .div(10**exchange.btDecimals)
            .div(exchange.fixedRate);
        uint256 marketFee = dtAmountOutSansFee.mul(exchange.marketFee).div(
            BASE
        );
        uint256 oceanFee = dtAmountOutSansFee.mul(exchange.oceanFee).div(BASE);
        dtAmountOut = dtAmountOutSansFee.sub(marketFee.add(oceanFee));
    }

    // FRE : Calc DT In Given BT Out
    function calcDatatokenInGivenBaseTokenOut(
        address exchangeAddress,
        bytes32 exchangeId,
        uint256 baseAmountOut
    ) public view returns (uint256 dtAmountIn) {
        IFixedRateExchange fre = IFixedRateExchange(exchangeAddress);
        Exchange memory exchange;
        exchange.fixedRate = fre.getRate(exchangeId);
        (exchange.marketFee, , exchange.oceanFee, , ) = fre.getFeesInfo(
            exchangeId
        );

        uint256 dtAmountInSansFee = baseAmountOut
            .mul(BONE)
            .mul(10**exchange.dtDecimals)
            .div(10**exchange.btDecimals)
            .div(exchange.fixedRate);
        uint256 marketFee = dtAmountInSansFee.mul(exchange.marketFee).div(BASE);
        uint256 oceanFee = dtAmountInSansFee.mul(exchange.oceanFee).div(BASE);
        dtAmountIn = dtAmountInSansFee.add(marketFee.add(oceanFee));
    }
}
