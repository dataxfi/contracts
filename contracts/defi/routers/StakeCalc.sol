pragma solidity >=0.8.0 <0.9.0;
//Copyright of DataX Protocol contributors
//SPDX-License-Identifier: BSU-1.1

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../interfaces/defi/IAdapter.sol";
import "../../interfaces/defi/IFeeCalc.sol";
import "../../interfaces/ocean/IPool.sol";
import "../utils/Const.sol";

contract StakeCalc is Const {
    using SafeMath for uint256;
    IFeeCalc fees;

    constructor(address _feeCalc) {
        fees = IFeeCalc(_feeCalc);
    }

    struct StakeInfo {
        address[4] meta; //[pool, to, refAddress, adapterAddress]
        uint256[3] uints; //[amountIn/maxAmountIn, refFees, amountOut/minAmountOut]
        address[] path;
    }

    //if staking, expected pool amount out given exact token amount in
    function calcPoolOutGivenTokenIn(StakeInfo calldata info)
        public
        view
        returns (
            uint256 poolAmountOut,
            uint256 dataxFee,
            uint256 refFee
        )
    {
        uint256 amountIn = info.uints[0];

        //skip if tokenOut is the baseToken
        if (info.path.length > 1) {
            IAdapter adapter = IAdapter(info.meta[3]);
            uint256[] memory amounts = adapter.getAmountsOut(
                info.uints[0],
                info.path
            );
            amountIn = amounts[amounts.length - 1];
        }

        (dataxFee, refFee) = fees.calcFees(
            amountIn,
            STAKE_FEE_TYPE,
            info.uints[1]
        );
        uint256 baseAmountIn = amountIn.sub(dataxFee.add(refFee));

        IPool pool = IPool(info.meta[0]);
        poolAmountOut = pool.calcPoolOutSingleIn(
            info.path[info.path.length - 1],
            baseAmountIn
        );
    }

    //if unstaking, calculate pool amount needed to get exact token amount out
    function calcPoolInGivenTokenOut(StakeInfo calldata info)
        public
        view
        returns (
            uint256 poolAmountIn,
            uint256 dataxFee,
            uint256 refFee
        )
    {
        uint256 amountOut = info.uints[2];

        //skip if tokenOut is the baseToken
        if (info.path.length > 1) {
            IAdapter adapter = IAdapter(info.meta[3]);
            uint256[] memory amounts = adapter.getAmountsIn(
                info.uints[2],
                info.path
            );
            amountOut = amounts[0];
        }

        (dataxFee, refFee) = fees.calcFees(
            amountOut,
            STAKE_FEE_TYPE,
            info.uints[1]
        );
        uint256 baseAmountNeeded = amountOut.add(dataxFee.add(refFee));

        IPool pool = IPool(info.meta[0]);
        poolAmountIn = pool.calcPoolInSingleOut(info.path[0], baseAmountNeeded);
    }

    //if unstaking, expected tokens out given exact pool amount in
    function calcTokenOutGivenPoolIn(StakeInfo calldata info)
        public
        view
        returns (
            uint256 baseAmountOut,
            uint256 dataxFee,
            uint256 refFee
        )
    {
        IPool pool = IPool(info.meta[0]);
        uint256 baseAmountOutSansFee = pool.calcSingleOutPoolIn(
            info.path[0],
            info.uints[0]
        );

        (dataxFee, refFee) = fees.calcFees(
            baseAmountOutSansFee,
            STAKE_FEE_TYPE,
            info.uints[1]
        );
        baseAmountOut = baseAmountOutSansFee.sub(dataxFee.add(refFee));

        //skip if tokenOut is the baseToken
        if (info.path.length > 1) {
            IAdapter adapter = IAdapter(info.meta[3]);
            uint256[] memory amountsOut = adapter.getAmountsOut(
                baseAmountOut,
                info.path
            );
            baseAmountOut = amountsOut[amountsOut.length - 1];
        }
    }
}
