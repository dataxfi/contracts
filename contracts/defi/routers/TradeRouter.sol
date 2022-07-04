pragma solidity >=0.8.0 <0.9.0;
//Copyright of DataX Protocol contributors
//SPDX-License-Identifier: BSU-1.1

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../utils/Const.sol";
import "../utils/Admin.sol";
import "../../interfaces/defi/IAdapter.sol";
import "../../interfaces/defi/IFRERouter.sol";
import "../../interfaces/defi/IPoolRouter.sol";
import "../../interfaces/ocean/IPool.sol";
import "../../interfaces/defi/IFeeCalc.sol";

contract TradeRouter is ReentrancyGuard, Const, Admin {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    IFeeCalc private fees;
    IFRERouter private freRouter;
    IPoolRouter private poolRouter;
    mapping(address => mapping(address => uint256)) public referralFees;

    event TradedETHToDataToken(
        address indexed tokenOut,
        address indexed baseToken,
        address from,
        address to,
        uint256 amount
    );
    event TradedDataTokenToETH(
        address indexed tokenIn,
        address indexed baseToken,
        address from,
        address to,
        uint256 amount
    );
    event TradedTokenToDataToken(
        address indexed tokenOut,
        address indexed baseToken,
        address indexed tokenIn,
        address from,
        address to,
        uint256 amount
    );
    event TradedDataTokenToToken(
        address indexed tokenIn,
        address indexed baseToken,
        address indexed tokenOut,
        address from,
        address to,
        uint256 amount
    );

    event ReferralFeesClaimed(
        address indexed referrer,
        address indexed token,
        uint256 claimedAmout
    );

    struct Exchange {
        uint256 dtDecimals;
        uint256 btDecimals;
        uint256 fixedRate;
        uint256 marketFee;
        uint256 oceanFee;
    }

    struct TradeInfo {
        address[6] meta; //[source, dtAddress, to, refAddress, adapterAddress, baseTokenAddress]
        uint256[4] uints; //[exactAmountIn/maxAmountIn, baseAmountNeeded, exactAmountOut/minAmountOut, refFees]
        address[] path;
        bool isFRE;
        bytes32 exchangeId;
    }

    constructor(
        address _poolRouter,
        address _freRouter,
        address _feeCalc
    ) {
        poolRouter = IPoolRouter(_poolRouter);
        freRouter = IFRERouter(_freRouter);
        fees = IFeeCalc(_feeCalc);
    }

    function swapETHToExactDatatoken(TradeInfo calldata info)
        external
        payable
        nonReentrant
        returns (
            uint256 baseRefund,
            uint256 ethRefund,
            uint256 dataxFee,
            uint256 refFee
        )
    {
        require(
            info.meta[2] != address(0),
            "TradeRouter: Destination address not provided"
        );
        IAdapter adapter = IAdapter(info.meta[4]);
        uint256 baseAmountOutSansFee;
        (dataxFee, refFee) = fees.calcFees(
            info.uints[1],
            TRADE_FEE_TYPE,
            info.uints[3]
        );

        uint256 baseAmountNeeded = info.uints[1].add(dataxFee).add(refFee);
        (baseAmountOutSansFee, ethRefund) = adapter.swapETHForExactTokens{
            value: msg.value
        }(baseAmountNeeded, info.path, address(this), msg.sender);
        uint256 baseAmountIn = baseAmountOutSansFee.sub(dataxFee.add(refFee));
        if (info.meta[2] != address(0)) {
            referralFees[info.meta[2]][info.meta[5]] = referralFees[
                info.meta[2]
            ][info.meta[5]].add(refFee);
        }
        if (info.isFRE) {
            IERC20(info.path[info.path.length - 1]).approve(
                address(freRouter),
                baseAmountIn
            );
            (, baseRefund) = freRouter.swapBaseTokenToExactDatatoken(
                info.path[info.path.length - 1],
                info.meta[2],
                info.meta[0],
                info.exchangeId,
                baseAmountIn,
                info.uints[2]
            );
        } else {
            IERC20(info.path[info.path.length - 1]).approve(
                address(poolRouter),
                baseAmountIn
            );
            (, baseRefund) = poolRouter.swapBaseTokenToExactDatatoken(
                info.path[info.path.length - 1],
                info.meta[1],
                info.meta[2],
                info.meta[0],
                baseAmountIn,
                info.uints[2]
            );
        }

        emit TradedETHToDataToken(
            info.meta[1],
            info.path[info.path.length - 1],
            msg.sender,
            info.meta[2],
            info.uints[1]
        );
    }

    function swapExactETHToDatatoken(TradeInfo calldata info)
        external
        payable
        nonReentrant
        returns (
            uint256 dtAmountOut,
            uint256 dataxFee,
            uint256 refFee
        )
    {
        require(
            info.meta[2] != address(0),
            "TradeRouter: Destination address not provided"
        );
        IAdapter adapter = IAdapter(info.meta[4]);
        (dataxFee, refFee) = fees.calcFees(
            info.uints[1],
            TRADE_FEE_TYPE,
            info.uints[3]
        );
        uint256 baseAmountOutSansFee = adapter.swapExactETHForTokens{
            value: msg.value
        }(info.uints[1], info.path, address(this));
        uint256 baseAmountIn = baseAmountOutSansFee.sub(dataxFee.add(refFee));
        if (info.meta[2] != address(0)) {
            referralFees[info.meta[2]][info.meta[5]] = referralFees[
                info.meta[2]
            ][info.meta[5]].add(refFee);
        }
        if (info.isFRE) {
            IERC20(info.path[info.path.length - 1]).approve(
                address(freRouter),
                baseAmountIn
            );
            freRouter.swapBaseTokenToExactDatatoken(
                info.path[info.path.length - 1],
                info.meta[2],
                info.meta[0],
                info.exchangeId,
                baseAmountIn,
                info.uints[2]
            );
            dtAmountOut = info.uints[2];
        } else {
            IERC20(info.path[info.path.length - 1]).approve(
                address(poolRouter),
                baseAmountIn
            );
            dtAmountOut = poolRouter.swapExactBaseTokenToDatatoken(
                info.path[info.path.length - 1],
                info.meta[1],
                info.meta[2],
                info.meta[0],
                baseAmountIn,
                info.uints[2]
            );
        }

        emit TradedETHToDataToken(
            info.meta[1],
            info.path[info.path.length - 1],
            msg.sender,
            info.meta[2],
            info.uints[1]
        );
    }

    function swapTokenToExactDatatoken(TradeInfo calldata info)
        external
        nonReentrant
        returns (
            uint256 baseRefund,
            uint256 tokenInRefund,
            uint256 dataxFee,
            uint256 refFee
        )
    {
        require(
            info.meta[2] != address(0),
            "TradeRouter: Destination address not provided"
        );

        IERC20 tokenIn = IERC20(info.path[0]);
        require(
            tokenIn.transferFrom(msg.sender, address(this), info.uints[0]),
            "TradeRouter: Self-transfer TokenIn Failed"
        );

        (dataxFee, refFee) = fees.calcFees(
            info.uints[1],
            TRADE_FEE_TYPE,
            info.uints[3]
        );

        uint256 baseAmountNeeded = info.uints[1].add(dataxFee).add(refFee);

        if (info.path.length > 1) {
            tokenIn.approve(info.meta[4], info.uints[0]);
            IAdapter adapter = IAdapter(info.meta[4]);
            (baseAmountNeeded, tokenInRefund) = adapter
                .swapTokensForExactTokens(
                    baseAmountNeeded,
                    info.uints[0],
                    info.path,
                    address(this),
                    msg.sender
                );
        }
        uint256 baseAmountIn = baseAmountNeeded.sub(dataxFee.add(refFee));
        if (info.meta[2] != address(0)) {
            referralFees[info.meta[2]][info.meta[5]] = referralFees[
                info.meta[2]
            ][info.meta[5]].add(refFee);
        }
        if (info.isFRE) {
            IERC20(info.path[info.path.length - 1]).approve(
                address(freRouter),
                baseAmountIn
            );
            (, baseRefund) = freRouter.swapBaseTokenToExactDatatoken(
                info.path[info.path.length - 1],
                info.meta[2],
                info.meta[0],
                info.exchangeId,
                baseAmountIn,
                info.uints[2]
            );
        } else {
            IERC20(info.path[info.path.length - 1]).approve(
                address(poolRouter),
                baseAmountIn
            );
            (, baseRefund) = poolRouter.swapBaseTokenToExactDatatoken(
                info.path[info.path.length - 1],
                info.meta[1],
                info.meta[2],
                info.meta[0],
                baseAmountIn,
                info.uints[2]
            );
        }

        emit TradedTokenToDataToken(
            info.meta[1],
            info.path[info.path.length - 1],
            info.path[0],
            msg.sender,
            info.meta[2],
            info.uints[1]
        );
    }

    function swapExactTokenToDatatoken(TradeInfo calldata info)
        external
        nonReentrant
        returns (
            uint256 dtAmountOut,
            uint256 dataxFee,
            uint256 refFee
        )
    {
        require(
            info.meta[2] != address(0),
            "TradeRouter: Destination address not provided"
        );

        IERC20 tokenIn = IERC20(info.path[0]);
        require(
            tokenIn.transferFrom(msg.sender, address(this), info.uints[0]),
            "TradeRouter: Self-transfer TokenIn Failed"
        );

        uint256 baseAmountOutSansFee = info.uints[1];

        (dataxFee, refFee) = fees.calcFees(
            baseAmountOutSansFee,
            TRADE_FEE_TYPE,
            info.uints[3]
        );

        if (info.path.length > 1) {
            tokenIn.approve(info.meta[4], info.uints[0]);
            IAdapter adapter = IAdapter(info.meta[4]);
            baseAmountOutSansFee = adapter.swapExactTokensForTokens(
                info.uints[0],
                baseAmountOutSansFee,
                info.path,
                address(this)
            );
        }
        uint256 baseAmountIn = baseAmountOutSansFee.sub(dataxFee.add(refFee));
        if (info.meta[2] != address(0)) {
            referralFees[info.meta[2]][info.meta[5]] = referralFees[
                info.meta[2]
            ][info.meta[5]].add(refFee);
        }
        if (info.isFRE) {
            IERC20(info.path[info.path.length - 1]).approve(
                address(freRouter),
                baseAmountIn
            );
            freRouter.swapBaseTokenToExactDatatoken(
                info.path[info.path.length - 1],
                info.meta[2],
                info.meta[0],
                info.exchangeId,
                baseAmountIn,
                info.uints[2]
            );
            dtAmountOut = info.uints[2];
        } else {
            IERC20(info.path[info.path.length - 1]).approve(
                address(poolRouter),
                baseAmountIn
            );
            dtAmountOut = poolRouter.swapExactBaseTokenToDatatoken(
                info.path[info.path.length - 1],
                info.meta[1],
                info.meta[2],
                info.meta[0],
                baseAmountIn,
                info.uints[2]
            );
        }

        emit TradedTokenToDataToken(
            info.meta[1],
            info.path[info.path.length - 1],
            info.path[0],
            msg.sender,
            info.meta[2],
            info.uints[1]
        );
    }

    function swapExactDatatokenToETH(TradeInfo calldata info)
        external
        nonReentrant
        returns (
            uint256 ethAmountOut,
            uint256 dataxFee,
            uint256 refFee
        )
    {
        require(
            info.meta[2] != address(0),
            "TradeRouter: Destination address not provided"
        );
        IERC20 tokenIn = IERC20(info.meta[1]);
        require(
            tokenIn.transferFrom(msg.sender, address(this), info.uints[0]),
            "TradeRouter: Self-transfer TokenIn Failed"
        );
        uint256 baseAmountOutSansFee;
        if (info.isFRE) {
            IERC20(info.meta[1]).approve(address(freRouter), info.uints[0]);
            baseAmountOutSansFee = freRouter.swapExactDatatokenToBaseToken(
                info.path[0],
                info.meta[1],
                address(this),
                info.meta[0],
                info.exchangeId,
                info.uints[0],
                info.uints[1]
            );
        } else {
            IERC20(info.meta[1]).approve(address(poolRouter), info.uints[0]);
            baseAmountOutSansFee = poolRouter.swapExactDatatokenToBaseToken(
                info.path[0],
                info.meta[1],
                address(this),
                info.meta[0],
                info.uints[0],
                info.uints[1]
            );
        }

        (dataxFee, refFee) = fees.calcFees(
            baseAmountOutSansFee,
            TRADE_FEE_TYPE,
            info.uints[3]
        );

        uint256 baseAmountIn = baseAmountOutSansFee.sub(dataxFee.add(refFee));
        if (info.meta[2] != address(0)) {
            referralFees[info.meta[2]][info.meta[5]] = referralFees[
                info.meta[2]
            ][info.meta[5]].add(refFee);
        }

        IAdapter adapter = IAdapter(info.meta[4]);
        IERC20(info.path[0]).approve(info.meta[4], baseAmountIn);
        ethAmountOut = adapter.swapExactTokensForETH(
            baseAmountIn,
            info.uints[2],
            info.path,
            info.meta[2]
        );

        emit TradedDataTokenToETH(
            info.meta[1],
            info.path[0],
            msg.sender,
            info.meta[2],
            info.uints[1]
        );
    }

    function swapDatatokenToExactETH(TradeInfo calldata info)
        external
        nonReentrant
        returns (
            uint256 tokenAmountIn,
            uint256 dataxFee,
            uint256 refFee
        )
    {
        require(
            info.meta[2] != address(0),
            "TradeRouter: Destination address not provided"
        );
        IERC20 tokenIn = IERC20(info.meta[1]);
        require(
            tokenIn.transferFrom(msg.sender, address(this), info.uints[0]),
            "TradeRouter: Self-transfer TokenIn Failed"
        );

        (dataxFee, refFee) = fees.calcFees(
            info.uints[1],
            TRADE_FEE_TYPE,
            info.uints[3]
        );

        uint256 baseAmountOutSansFee = info.uints[1].add(dataxFee.add(refFee));

        if (info.isFRE) {
            IERC20(info.meta[1]).approve(address(freRouter), info.uints[0]);
            baseAmountOutSansFee = freRouter.swapExactDatatokenToBaseToken(
                info.path[0],
                info.meta[1],
                address(this),
                info.meta[0],
                info.exchangeId,
                info.uints[0],
                baseAmountOutSansFee
            );
        } else {
            IERC20(info.meta[1]).approve(address(poolRouter), info.uints[0]);
            poolRouter.swapDatatokenToExactBaseToken(
                info.path[0],
                info.meta[1],
                address(this),
                info.meta[0],
                info.uints[0],
                baseAmountOutSansFee
            );
        }

        if (info.meta[2] != address(0)) {
            referralFees[info.meta[2]][info.meta[5]] = referralFees[
                info.meta[2]
            ][info.meta[5]].add(refFee);
        }

        IAdapter adapter = IAdapter(info.meta[4]);
        IERC20(info.path[0]).approve(info.meta[4], info.uints[1]);
        (tokenAmountIn, ) = adapter.swapTokensForExactETH(
            info.uints[2],
            info.uints[1],
            info.path,
            info.meta[2],
            info.meta[2]
        );

        emit TradedDataTokenToETH(
            info.meta[1],
            info.path[0],
            msg.sender,
            info.meta[2],
            info.uints[1]
        );
    }

    function swapExactDatatokenToToken(TradeInfo calldata info)
        external
        nonReentrant
        returns (
            uint256 tokenAmountOut,
            uint256 dataxFee,
            uint256 refFee
        )
    {
        require(
            info.meta[2] != address(0),
            "TradeRouter: Destination address not provided"
        );
        IERC20 tokenIn = IERC20(info.meta[1]);
        require(
            tokenIn.transferFrom(msg.sender, address(this), info.uints[0]),
            "TradeRouter: Self-transfer TokenIn Failed"
        );
        uint256 baseAmountOutSansFee;
        if (info.isFRE) {
            IERC20(info.meta[1]).approve(address(freRouter), info.uints[0]);
            baseAmountOutSansFee = freRouter.swapExactDatatokenToBaseToken(
                info.path[0],
                info.meta[1],
                address(this),
                info.meta[0],
                info.exchangeId,
                info.uints[0],
                info.uints[1]
            );
        } else {
            IERC20(info.meta[1]).approve(address(poolRouter), info.uints[0]);
            baseAmountOutSansFee = poolRouter.swapExactDatatokenToBaseToken(
                info.path[0],
                info.meta[1],
                address(this),
                info.meta[0],
                info.uints[0],
                info.uints[1]
            );
        }

        (dataxFee, refFee) = fees.calcFees(
            baseAmountOutSansFee,
            TRADE_FEE_TYPE,
            info.uints[3]
        );

        tokenAmountOut = baseAmountOutSansFee.sub(dataxFee.add(refFee));
        if (info.meta[2] != address(0)) {
            referralFees[info.meta[2]][info.meta[5]] = referralFees[
                info.meta[2]
            ][info.meta[5]].add(refFee);
        }

        if (info.path.length > 1) {
            IAdapter adapter = IAdapter(info.meta[4]);
            IERC20(info.path[0]).approve(info.meta[4], tokenAmountOut);
            tokenAmountOut = adapter.swapExactTokensForTokens(
                tokenAmountOut,
                info.uints[2],
                info.path,
                info.meta[2]
            );
        } else {
            IERC20(info.path[0]).safeTransfer(info.meta[2], tokenAmountOut);
        }

        emit TradedDataTokenToToken(
            info.meta[1],
            info.path[info.path.length - 1],
            info.path[0],
            msg.sender,
            info.meta[2],
            info.uints[1]
        );
    }

    function swapDatatokenToExactToken(TradeInfo calldata info)
        external
        nonReentrant
        returns (
            uint256 tokenAmountIn,
            uint256 dataxFee,
            uint256 refFee
        )
    {
        require(
            info.meta[2] != address(0),
            "TradeRouter: Destination address not provided"
        );
        IERC20 tokenIn = IERC20(info.meta[1]);
        require(
            tokenIn.transferFrom(msg.sender, address(this), info.uints[0]),
            "TradeRouter: Self-transfer TokenIn Failed"
        );

        (dataxFee, refFee) = fees.calcFees(
            info.uints[1],
            TRADE_FEE_TYPE,
            info.uints[3]
        );

        uint256 baseAmountOutSansFee = info.uints[1].add(dataxFee.add(refFee));

        if (info.isFRE) {
            IERC20(info.meta[1]).approve(address(freRouter), info.uints[0]);
            baseAmountOutSansFee = freRouter.swapExactDatatokenToBaseToken(
                info.path[0],
                info.meta[1],
                address(this),
                info.meta[0],
                info.exchangeId,
                info.uints[0],
                baseAmountOutSansFee
            );
        } else {
            IERC20(info.meta[1]).approve(address(poolRouter), info.uints[0]);
            (tokenAmountIn, ) = poolRouter.swapDatatokenToExactBaseToken(
                info.path[0],
                info.meta[1],
                address(this),
                info.meta[0],
                info.uints[0],
                baseAmountOutSansFee
            );
        }

        if (info.meta[2] != address(0)) {
            referralFees[info.meta[2]][info.meta[5]] = referralFees[
                info.meta[2]
            ][info.meta[5]].add(refFee);
        }

        if (info.path.length > 1) {
            IAdapter adapter = IAdapter(info.meta[4]);
            IERC20(info.path[0]).approve(info.meta[4], info.uints[1]);
            adapter.swapTokensForExactTokens(
                info.uints[2],
                info.uints[1],
                info.path,
                info.meta[2],
                info.meta[2]
            );
        } else {
            IERC20(info.path[0]).safeTransfer(info.meta[2], info.uints[1]);
        }

        emit TradedDataTokenToToken(
            info.meta[1],
            info.path[info.path.length - 1],
            info.path[0],
            msg.sender,
            info.meta[2],
            info.uints[1]
        );
    }

    //claim collected Referral fees
    function claimRefFees(address token, address referrer)
        external
        nonReentrant
        returns (uint256 claimAmount)
    {
        IERC20 baseToken = IERC20(token);
        claimAmount = referralFees[referrer][token];
        require(claimAmount > 0, "StakeRouter: No tokens to claim");
        //reset claimable amount
        referralFees[referrer][token] = 0;
        //transfer tokens to referrer
        baseToken.safeTransfer(referrer, claimAmount);

        emit ReferralFeesClaimed(referrer, token, claimAmount);
    }

    //receive ETH
    receive() external payable {}
}
