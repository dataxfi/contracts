/*

pragma solidity >=0.8.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface PoolInterface {
    function swapExactAmountIn(
        address,
        uint256,
        address,
        uint256,
        uint256
    ) external returns (uint256, uint256);

    function swapExactAmountOut(
        address,
        uint256,
        address,
        uint256,
        uint256
    ) external returns (uint256, uint256);

    function calcInGivenOut(
        uint256,
        uint256,
        uint256,
        uint256,
        uint256,
        uint256
    ) external pure returns (uint256);

    function calcOutGivenIn(
        uint256,
        uint256,
        uint256,
        uint256,
        uint256,
        uint256
    ) external pure returns (uint256);

    function getDenormalizedWeight(address) external view returns (uint256);

    function getBalance(address) external view returns (uint256);

    function getSwapFee() external view returns (uint256);
}

interface TokenInterface {
    function balanceOf(address) external view returns (uint256);

    function allowance(address, address) external view returns (uint256);

    function approve(address, uint256) external returns (bool);

    function transfer(address, uint256) external returns (bool);

    function transferFrom(
        address,
        address,
        uint256
    ) external returns (bool);

    function deposit() external payable;

    function withdraw(uint256) external;
}

contract DataxRouter is Ownable {
    using SafeMath for uint256;

    struct Pool {
        address pool;
        uint256 tokenBalanceIn;
        uint256 tokenWeightIn;
        uint256 tokenBalanceOut;
        uint256 tokenWeightOut;
        uint256 swapFee;
        uint256 effectiveLiquidity;
    }

    struct Swap {
        address pool;
        address tokenIn;
        address tokenOut;
        uint256 swapAmount; // tokenInAmount / tokenOutAmount
        uint256 limitReturnAmount; // minAmountOut / maxAmountIn
        uint256 maxPrice;
    }

    TokenInterface weth;
    address private constant ETH_ADDRESS =
        address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
    uint256 private constant BONE = 10**18;

    constructor(address _weth) public {
        weth = TokenInterface(_weth);
    }

    function swapExactDtToDt(
        Swap[][] memory swapSequences,
        TokenInterface tokenIn,
        TokenInterface tokenOut,
        uint256 totalAmountIn,
        uint256 minTotalAmountOut
    ) public payable returns (uint256 totalAmountOut) {
        transferFromAll(tokenIn, totalAmountIn);

        for (uint256 i = 0; i < swapSequences.length; i++) {
            uint256 tokenAmountOut;
            for (uint256 k = 0; k < swapSequences[i].length; k++) {
                Swap memory swap = swapSequences[i][k];
                TokenInterface SwapTokenIn = TokenInterface(swap.tokenIn);
                if (k == 1) {
                    // Makes sure that on the second swap the output of the first was used
                    // so there is not intermediate token leftover
                    swap.swapAmount = tokenAmountOut;
                }

                PoolInterface pool = PoolInterface(swap.pool);
                if (SwapTokenIn.allowance(address(this), swap.pool) > 0) {
                    SwapTokenIn.approve(swap.pool, 0);
                }
                SwapTokenIn.approve(swap.pool, swap.swapAmount);
                (tokenAmountOut, ) = pool.swapExactAmountIn(
                    swap.tokenIn,
                    swap.swapAmount,
                    swap.tokenOut,
                    swap.limitReturnAmount,
                    swap.maxPrice
                );
            }
            // This takes the amountOut of the last swap
            totalAmountOut = tokenAmountOut.add(totalAmountOut);
        }

        require(totalAmountOut >= minTotalAmountOut, "ERR_LIMIT_OUT");

        transferAll(tokenOut, totalAmountOut);
        transferAll(tokenIn, getBalance(tokenIn));
    }

    function swapDtToExactDt(
        Swap[] memory swapSequences,
        TokenInterface tokenIn,
        TokenInterface tokenOut,
        uint256 maxTotalAmountIn
    ) public payable returns (uint256 tokenAmountInFirstSwap) {
        transferFromAll(tokenIn, maxTotalAmountIn);

        // Specific code for a simple swap and a multihop (2 swaps in sequence)

        // Consider we are swapping A -> B and B -> C. The goal is to buy a given amount
        // of token C. But first we need to buy B with A so we can then buy C with B
        // To get the exact amount of C we then first need to calculate how much B we'll need:
        uint256 intermediateTokenAmount; // This would be token B as described above
        Swap memory secondSwap = swapSequences[1];
        PoolInterface poolSecondSwap = PoolInterface(secondSwap.pool);
        intermediateTokenAmount = poolSecondSwap.calcInGivenOut(
            poolSecondSwap.getBalance(secondSwap.tokenIn),
            poolSecondSwap.getDenormalizedWeight(secondSwap.tokenIn),
            poolSecondSwap.getBalance(secondSwap.tokenOut),
            poolSecondSwap.getDenormalizedWeight(secondSwap.tokenOut),
            secondSwap.swapAmount,
            poolSecondSwap.getSwapFee()
        );

        //// Buy intermediateTokenAmount of token B with A in the first pool
        Swap memory firstSwap = swapSequences[0];
        TokenInterface FirstSwapTokenIn = TokenInterface(firstSwap.tokenIn);
        PoolInterface poolFirstSwap = PoolInterface(firstSwap.pool);
        if (
            FirstSwapTokenIn.allowance(address(this), firstSwap.pool) <
            uint256(-1)
        ) {
            FirstSwapTokenIn.approve(firstSwap.pool, uint256(-1));
        }

        (tokenAmountInFirstSwap, ) = poolFirstSwap.swapExactAmountOut(
            firstSwap.tokenIn,
            firstSwap.limitReturnAmount,
            firstSwap.tokenOut,
            intermediateTokenAmount, // This is the amount of token B we need
            firstSwap.maxPrice
        );

        //// Buy the final amount of token C desired
        TokenInterface SecondSwapTokenIn = TokenInterface(secondSwap.tokenIn);
        if (
            SecondSwapTokenIn.allowance(address(this), secondSwap.pool) <
            uint256(-1)
        ) {
            SecondSwapTokenIn.approve(secondSwap.pool, uint256(-1));
        }

        poolSecondSwap.swapExactAmountOut(
            secondSwap.tokenIn,
            secondSwap.limitReturnAmount,
            secondSwap.tokenOut,
            secondSwap.swapAmount,
            secondSwap.maxPrice
        );

        require(tokenAmountInFirstSwap <= maxTotalAmountIn, "ERR_LIMIT_INN");

        transferAll(tokenOut, getBalance(tokenOut));
        transferAll(tokenIn, getBalance(tokenIn));
    }

    function transferFromAll(TokenInterface token, uint256 amount)
        internal
        returns (bool)
    {
        if (isETH(token)) {
            weth.deposit.value(msg.value)();
        } else {
            require(
                token.transferFrom(msg.sender, address(this), amount),
                "ERR_TRANSFER_FAILED"
            );
        }
    }

    function getBalance(TokenInterface token) internal view returns (uint256) {
        if (isETH(token)) {
            return weth.balanceOf(address(this));
        } else {
            return token.balanceOf(address(this));
        }
    }

    function transferAll(TokenInterface token, uint256 amount)
        internal
        returns (bool)
    {
        if (amount == 0) {
            return true;
        }

        if (isETH(token)) {
            weth.withdraw(amount);
            (bool xfer, ) = msg.sender.call.value(amount)("");
            require(xfer, "ERR_ETH_FAILED");
        } else {
            require(token.transfer(msg.sender, amount), "ERR_TRANSFER_FAILED");
        }
    }

    function isETH(TokenInterface token) internal pure returns (bool) {
        return (address(token) == ETH_ADDRESS);
    }

    fallback() external {}
}

*/