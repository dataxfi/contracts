pragma solidity >=0.8.0 <0.9.0;
//Copyright of DataX Protocol contributors
//SPDX-License-Identifier: BSU-1.1

import "../../interfaces/defi/IAdapter.sol";
import "../../interfaces/ocean/IPool.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../utils/Math.sol";
import "hardhat/console.sol";

contract PoolRouter is ReentrancyGuard, Math {
    using SafeMath for uint256;
    uint8 public version;
    uint256 private constant ZERO_FEES = 0;
    uint256 private constant MAX_INT = 2**256 - 1;

    constructor(uint8 _version) {
        version = _version;
    }

    // Pool : DT to Exact BT
    function swapDatatokenToExactBaseToken(
        address baseTokenAddress,
        address datatokenAddress,
        address to,
        address poolAddress,
        uint256 maxDtAmountIn,
        uint256 baseAmountOut
    ) public returns (uint256 dtAmountIn, uint256 toRefund) {
        IERC20 datatoken = IERC20(datatokenAddress);
        require(
            datatoken.balanceOf(msg.sender) >= maxDtAmountIn,
            "TradeRouter: Not enough Datatoken"
        );
        IERC20 baseToken = IERC20(baseTokenAddress);
        IPool pool = IPool(poolAddress);
        if (msg.sender != address(this)) {
            require(
                datatoken.transferFrom(
                    msg.sender,
                    address(this),
                    maxDtAmountIn
                ),
                "TradeRouter: Self-transfer Datatoken Failed"
            );
        }
        require(
            datatoken.approve(poolAddress, maxDtAmountIn),
            "TradeRouter: Failed to approve Datatoken on Pool"
        );
        address[3] memory tokenInOutMarket = [
            datatokenAddress,
            baseTokenAddress,
            address(0)
        ];
        uint256[4] memory amountsInOutMaxFee = [
            maxDtAmountIn,
            baseAmountOut,
            MAX_INT,
            ZERO_FEES
        ];
        (dtAmountIn, ) = pool.swapExactAmountOut(
            tokenInOutMarket,
            amountsInOutMaxFee
        );
        require(
            baseToken.transfer(to, baseAmountOut),
            "TradeRouter: BaseToken transfer failed"
        );
        toRefund = maxDtAmountIn.sub(dtAmountIn);
        if (toRefund > 0) {
            require(
                datatoken.transfer(to, toRefund),
                "TradeRouter: Datatoken refund failed"
            );
        }
    }

    // Pool : Exact DT to BT
    function swapExactDatatokenToBaseToken(
        address baseTokenAddress,
        address datatokenAddress,
        address to,
        address poolAddress,
        uint256 dtAmountIn,
        uint256 minBaseAmountOut
    ) public returns (uint256 baseAmountOut) {
        IERC20 datatoken = IERC20(datatokenAddress);
        require(
            datatoken.balanceOf(msg.sender) >= dtAmountIn,
            "TradeRouter: Not enough Datatoken"
        );
        IERC20 baseToken = IERC20(baseTokenAddress);
        IPool pool = IPool(poolAddress);
        if (msg.sender != address(this)) {
            require(
                datatoken.transferFrom(msg.sender, address(this), dtAmountIn),
                "TradeRouter: Self-transfer Datatoken Failed"
            );
        }
        require(
            datatoken.approve(poolAddress, dtAmountIn),
            "TradeRouter: Failed to approve Datatoken on Pool"
        );
        address[3] memory tokenInOutMarket = [
            datatokenAddress,
            baseTokenAddress,
            address(0)
        ];
        uint256[4] memory amountsInOutMaxFee = [
            dtAmountIn,
            minBaseAmountOut,
            MAX_INT,
            ZERO_FEES
        ];
        (baseAmountOut, ) = pool.swapExactAmountIn(
            tokenInOutMarket,
            amountsInOutMaxFee
        );
        require(
            baseToken.transfer(to, baseAmountOut),
            "TradeRouter: BaseToken transfer failed"
        );
    }

    // Pool : BT to Exact DT
    function swapBaseTokenToExactDatatoken(
        address baseTokenAddress,
        address datatokenAddress,
        address to,
        address poolAddress,
        uint256 maxBaseAmountIn,
        uint256 dtAmountOut
    ) public returns (uint256 baseAmountIn, uint256 toRefund) {
        IERC20 baseToken = IERC20(baseTokenAddress);
        require(
            baseToken.balanceOf(msg.sender) >= maxBaseAmountIn,
            "TradeRouter: Not enough BaseToken"
        );
        IPool pool = IPool(poolAddress);
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
            baseToken.approve(poolAddress, maxBaseAmountIn),
            "TradeRouter: Failed to approve Basetoken on Pool"
        );
        address[3] memory tokenInOutMarket = [
            baseTokenAddress,
            datatokenAddress,
            address(0)
        ];
        uint256[4] memory amountsInOutMaxFee = [
            maxBaseAmountIn,
            dtAmountOut,
            MAX_INT,
            ZERO_FEES
        ];
        (baseAmountIn, ) = pool.swapExactAmountOut(
            tokenInOutMarket,
            amountsInOutMaxFee
        );
        require(
            IERC20(datatokenAddress).transfer(to, dtAmountOut),
            "TradeRouter: DT transfer failed"
        );
        toRefund = maxBaseAmountIn.sub(baseAmountIn);
        if (toRefund > 0) {
            require(
                baseToken.transfer(to, toRefund),
                "TradeRouter: BaseToken refund failed"
            );
        }
    }

    // Pool : Exact BT to DT
    function swapExactBaseTokenToDatatoken(
        address baseTokenAddress,
        address datatokenAddress,
        address to,
        address poolAddress,
        uint256 baseAmountIn,
        uint256 minDtAmountOut
    ) public returns (uint256 dtAmountOut) {
        IERC20 baseToken = IERC20(baseTokenAddress);
        require(
            baseToken.balanceOf(msg.sender) >= baseAmountIn,
            "TradeRouter: Not enough BaseToken"
        );
        if (msg.sender != address(this)) {
            require(
                baseToken.transferFrom(msg.sender, address(this), baseAmountIn),
                "TradeRouter: Self-transfer Basetoken Failed"
            );
        }
        require(
            baseToken.approve(poolAddress, baseAmountIn),
            "TradeRouter: Failed to approve Basetoken on Pool"
        );
        address[3] memory tokenInOutMarket = [
            baseTokenAddress,
            datatokenAddress,
            address(0)
        ];
        uint256[4] memory amountsInOutMaxFee = [
            baseAmountIn,
            minDtAmountOut,
            MAX_INT,
            ZERO_FEES
        ];
        IPool pool = IPool(poolAddress);
        (dtAmountOut, ) = pool.swapExactAmountIn(
            tokenInOutMarket,
            amountsInOutMaxFee
        );
        require(
            IERC20(datatokenAddress).transfer(to, dtAmountOut),
            "TradeRouter: DT transfer failed"
        );
    }
}
