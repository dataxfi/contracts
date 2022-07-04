pragma solidity >=0.8.0 <0.9.0;
//Copyright of DataX Protocol contributors
//SPDX-License-Identifier: BSU-1.1

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../utils/Const.sol";
import "../../interfaces/defi/IFeeCalc.sol";
import "../../interfaces/defi/IAdapter.sol";
import "../../interfaces/ocean/IPool.sol";
import "../../interfaces/defi/IPoolRouter.sol";
import "../../interfaces/defi/IFRERouter.sol";
import "hardhat/console.sol";

contract TradeCalc is Const {
    using SafeMath for uint256;
    IFeeCalc fees;
    IFRERouter private freRouter;

    struct TradeInfo {
        address[6] meta; //[source, dtAddress, to, refAddress, adapterAddress, baseTokenAddress]
        uint256[4] uints; //[exactAmountIn/maxAmountIn, baseAmountNeeded, exactAmountOut/minAmountOut, refFees]
        address[] path;
        bool isFRE;
        bytes32 exchangeId;
    }

    constructor(address _freRouter, address _feeCalc) {
        freRouter = IFRERouter(_freRouter);
        fees = IFeeCalc(_feeCalc);
    }

    /********** Calculations *************/

    // calculate DT Out Token In
    function calcDatatokenOutGivenTokenIn(TradeInfo calldata info)
        public
        view
        returns (
            uint256 dtAmountOut,
            uint256 baseAmountNeeded,
            uint256 dataxFee,
            uint256 refFee
        )
    {
        baseAmountNeeded = info.uints[0];

        if (info.path.length > 1) {
            IAdapter adapter = IAdapter(info.meta[4]);
            uint256[] memory amounts = adapter.getAmountsOut(
                info.uints[0],
                info.path
            );
            baseAmountNeeded = amounts[amounts.length - 1];
        }

        (dataxFee, refFee) = fees.calcFees(
            baseAmountNeeded,
            TRADE_FEE_TYPE,
            info.uints[3]
        );
        uint256 baseAmountIn = baseAmountNeeded.sub(dataxFee.add(refFee));
        if (info.isFRE) {
            dtAmountOut = freRouter.calcDatatokenOutGivenBaseTokenIn(
                info.meta[0],
                info.exchangeId,
                baseAmountIn
            );
        } else {
            IPool pool = IPool(info.meta[0]);
            (dtAmountOut, , , , ) = pool.getAmountOutExactIn(
                info.meta[5],
                info.meta[1],
                baseAmountIn,
                ZERO_FEES
            );
        }
    }

    // calculate Token Out DT In
    function calcTokenOutGivenDatatokenIn(TradeInfo calldata info)
        public
        view
        returns (
            uint256 tokenAmountOut,
            uint256 baseAmountNeeded,
            uint256 dataxFee,
            uint256 refFee
        )
    {
        // calc DT -> BT
        if (info.isFRE) {
            baseAmountNeeded = freRouter.calcBaseTokenOutGivenDatatokenIn(
                info.meta[0],
                info.exchangeId,
                info.uints[0]
            );
        } else {
            IPool pool = IPool(info.meta[0]);
            (baseAmountNeeded, , , , ) = pool.getAmountOutExactIn(
                info.meta[1],
                info.meta[5],
                info.uints[0],
                ZERO_FEES
            );
        }

        //calc Fee
        (dataxFee, refFee) = fees.calcFees(
            baseAmountNeeded,
            TRADE_FEE_TYPE,
            info.uints[3]
        );

        tokenAmountOut = baseAmountNeeded.sub(dataxFee.add(refFee));
        if (info.path.length > 1) {
            // calc BT -> Token
            IAdapter adapter = IAdapter(info.meta[4]);
            uint256[] memory amounts = adapter.getAmountsOut(
                tokenAmountOut,
                info.path
            );
            tokenAmountOut = amounts[amounts.length - 1];
        }
    }

    // calculate DT In Token Out
    function calcDatatokenInGivenTokenOut(TradeInfo calldata info)
        public
        view
        returns (
            uint256 dtAmountIn,
            uint256 baseAmountNeeded,
            uint256 dataxFee,
            uint256 refFee
        )
    {
        baseAmountNeeded = info.uints[2];
        if (info.path.length > 1) {
            IAdapter adapter = IAdapter(info.meta[4]);
            uint256[] memory amounts = adapter.getAmountsIn(
                info.uints[2],
                info.path
            );
            baseAmountNeeded = amounts[0];
        }

        (dataxFee, refFee) = fees.calcFees(
            baseAmountNeeded,
            TRADE_FEE_TYPE,
            info.uints[3]
        );
        uint256 baseAmountOut = baseAmountNeeded.add(dataxFee.add(refFee));
        if (info.isFRE) {
            dtAmountIn = freRouter.calcDatatokenInGivenBaseTokenOut(
                info.meta[0],
                info.exchangeId,
                baseAmountOut
            );
        } else {
            IPool pool = IPool(info.meta[0]);
            (dtAmountIn, , , , ) = pool.getAmountInExactOut(
                info.meta[1],
                info.meta[5],
                baseAmountOut,
                ZERO_FEES
            );
        }
    }

    // calculate Token In DT Out
    function calcTokenInGivenDatatokenOut(TradeInfo calldata info)
        public
        view
        returns (
            uint256 tokenAmountIn,
            uint256 baseAmountNeeded,
            uint256 dataxFee,
            uint256 refFee
        )
    {
        if (info.isFRE) {
            baseAmountNeeded = freRouter.calcBaseTokenInGivenDatatokenOut(
                info.meta[0],
                info.exchangeId,
                info.uints[2]
            );
        } else {
            IPool pool = IPool(info.meta[0]);
            (baseAmountNeeded, , , , ) = pool.getAmountInExactOut(
                info.meta[5],
                info.meta[1],
                info.uints[2],
                ZERO_FEES
            );
        }
        (dataxFee, refFee) = fees.calcFees(
            baseAmountNeeded,
            TRADE_FEE_TYPE,
            info.uints[3]
        );
        tokenAmountIn = baseAmountNeeded.add(dataxFee.add(refFee));
        if (info.path.length > 1) {
            IAdapter adapter = IAdapter(info.meta[4]);
            uint256[] memory amountsIn = adapter.getAmountsIn(
                tokenAmountIn,
                info.path
            );
            tokenAmountIn = amountsIn[0];
        }
    }
}
