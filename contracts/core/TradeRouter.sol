pragma solidity >=0.8.0 <0.9.0;
//Copyright of DataX Protocol contributors
//SPDX-License-Identifier: BSU-1.1

import "../interfaces/IAdapter.sol";
import "../interfaces/ITradeRouter.sol";
import "../interfaces/ocean/IPool.sol";
import "../interfaces/ocean/IFactoryRouter.sol";
import "../interfaces/ocean/IFixedRateExchange.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../utils/Math.sol";
import "../interfaces/IPoolRouter.sol";
import "../interfaces/IFRERouter.sol";
import "hardhat/console.sol";

contract TradeRouter is ReentrancyGuard, Math {
    using SafeMath for uint256;
    IStorage store;
    uint8 public version;
    mapping(address => uint256) public referralFees;
    string public constant TRADE_FEE_TYPE = "TRADE";
    uint256 private constant ZERO_FEES = 0;
    uint256 private constant MAX_INT = 2**256 - 1;
    uint256 private constant BASE = 1e18;
    IPoolRouter private poolRouter;
    IFRERouter private freRouter;

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

    struct Exchange {
        uint256 dtDecimals;
        uint256 btDecimals;
        uint256 fixedRate;
        uint256 marketFee;
        uint256 oceanFee;
    }

    struct TradeInfo {
        address[5] meta; //[source, dtAddress, to, refAddress, adapterAddress]
        uint256[4] uints; //[exactAmountIn/maxAmountIn, baseAmountNeeded, exactAmountOut/minAmountOut, refFees]
        address[] path;
        bool isFRE;
        bytes32 exchangeId;
    }

    constructor(
        uint8 _version,
        address _storage,
        address _poolRouter,
        address _freRouter
    ) {
        version = _version;
        store = IStorage(_storage);
        poolRouter = IPoolRouter(_poolRouter);
        freRouter = IFRERouter(_freRouter);
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
        (dataxFee, refFee) = calcFees(
            info.uints[1],
            TRADE_FEE_TYPE,
            info.uints[3]
        );
        console.log("TR : baseAmountOut - ", info.uints[1]);
        uint256 baseAmountNeeded = info.uints[1].add(dataxFee).add(refFee);
        console.log("TR : baseAmountNeeded - ", baseAmountNeeded);
        (baseAmountOutSansFee, ethRefund) = adapter.swapETHForExactTokens{
            value: msg.value
        }(baseAmountNeeded, info.path, address(this), msg.sender);
        console.log("TR : baseAmountOutSansFee - ", baseAmountOutSansFee);
        uint256 baseAmountIn = baseAmountOutSansFee.sub(dataxFee.add(refFee));
        console.log("TR : baseAmountIn - ", baseAmountIn);
        if (info.meta[2] != address(0)) {
            referralFees[info.meta[2]] = referralFees[info.meta[2]].add(refFee);
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
            msg.sender,
            info.meta[2],
            info.uints[2]
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
        (dataxFee, refFee) = calcFees(
            info.uints[1],
            TRADE_FEE_TYPE,
            info.uints[3]
        );
        uint256 baseAmountOutSansFee = adapter.swapExactETHForTokens{
            value: msg.value
        }(info.uints[1], info.path, address(this));
        uint256 baseAmountIn = baseAmountOutSansFee.sub(dataxFee.add(refFee));
        if (info.meta[2] != address(0)) {
            referralFees[info.meta[2]] = referralFees[info.meta[2]].add(refFee);
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
            msg.sender,
            info.meta[2],
            info.uints[2]
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

        (dataxFee, refFee) = calcFees(
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
            referralFees[info.meta[2]] = referralFees[info.meta[2]].add(refFee);
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
            info.path[0],
            msg.sender,
            info.meta[2],
            info.uints[2]
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

        (dataxFee, refFee) = calcFees(
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
            referralFees[info.meta[2]] = referralFees[info.meta[2]].add(refFee);
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
            info.path[0],
            msg.sender,
            info.meta[2],
            info.uints[2]
        );
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

        (dataxFee, refFee) = calcFees(
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
                info.path[info.path.length - 1],
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
            (baseAmountNeeded, , , , ) = pool.getAmountInExactOut(
                info.meta[1],
                info.path[info.path.length - 1],
                info.uints[0],
                ZERO_FEES
            );
        }
        //calc Fee
        (dataxFee, refFee) = calcFees(
            baseAmountNeeded,
            TRADE_FEE_TYPE,
            info.uints[3]
        );

        tokenAmountOut = baseAmountNeeded.sub(dataxFee.add(refFee));
        if (info.path.length > 1) {
            // calc BT -> Token
            IAdapter adapter = IAdapter(info.meta[4]);
            uint256[] memory amountsIn = adapter.getAmountsIn(
                tokenAmountOut,
                info.path
            );
            tokenAmountOut = amountsIn[0];
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
        IAdapter adapter = IAdapter(info.meta[4]);
        uint256[] memory amounts = adapter.getAmountsIn(
            info.uints[2],
            info.path
        );
        baseAmountNeeded = amounts[0];
        (dataxFee, refFee) = calcFees(
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
                info.path[0],
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
                info.path[info.path.length - 1],
                info.meta[1],
                info.uints[2],
                ZERO_FEES
            );
        }
        (dataxFee, refFee) = calcFees(
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

    //calculate fees
    function calcFees(
        uint256 baseAmount,
        string memory feeType,
        uint256 refFeeRate
    ) public view returns (uint256 dataxFee, uint256 refFee) {
        uint256 feeRate = store.getFees(feeType);
        require(
            refFeeRate <= bsub(BONE, feeRate),
            "TradeRouter: Ref Fees too high"
        );

        // DataX Fees
        if (feeRate != 0) {
            dataxFee = bsub(baseAmount, bmul(baseAmount, bsub(BONE, feeRate)));
        }
        // Referral fees
        if (refFeeRate != 0) {
            refFee = bsub(baseAmount, bmul(baseAmount, bsub(BONE, refFeeRate)));
        }
    }

    //receive ETH
    receive() external payable {}
}
