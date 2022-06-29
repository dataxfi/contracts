pragma solidity >=0.8.0 <0.9.0;
//Copyright of DataX Protocol contributors
//SPDX-License-Identifier: BSU-1.1

import "../../interfaces/defi/IAdapter.sol";
import "../../interfaces/ocean/IPool.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../utils/Fee.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract StakeRouter is ReentrancyGuard, Fee {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    mapping(address => mapping(address => uint256)) public referralFees;
    string constant STAKE_FEE_TYPE = "STAKE";
    string constant UNSTAKE_FEE_TYPE = "UNSTAKE";

    event StakedETHInPool(
        address indexed pool,
        address indexed beneficiary,
        address referrer,
        uint256 amountInETH,
        uint256 amountInBasetoken
    );

    event StakedTokenInPool(
        address indexed pool,
        address indexed token,
        address indexed beneficiary,
        address referrer,
        uint256 amountInToken,
        uint256 amountInBasetoken
    );

    event UnstakedETHFromPool(
        address indexed pool,
        address indexed beneficiary,
        address referrer,
        uint256 amountInETH,
        uint256 amountInBasetoken
    );

    event UnstakedTokenFromPool(
        address indexed pool,
        address indexed token,
        address indexed beneficiary,
        address referrer,
        uint256 amountInToken,
        uint256 amountInBasetoken
    );

    event ReferralFeesClaimed(
        address indexed referrer,
        address indexed token,
        uint256 claimedAmout
    );

    struct StakeInfo {
        address[4] meta; //[pool, to, refAddress, adapterAddress]
        uint256[3] uints; //[amountIn/maxAmountIn, refFees, amountOut/minAmountOut]
        address[] path;
    }

    constructor() {
        admin = msg.sender;
    }

    function stakeETHInDTPool(StakeInfo calldata info)
        external
        payable
        nonReentrant
        returns (uint256 poolTokensOut)
    {
        require(
            info.meta[2] != address(0),
            "StakeRouter: Destination address not provided"
        );

        require(info.path.length > 1, "StakeRouter: Path too short");

        //TODO: deduct trade fee + ref fee
        IAdapter adapter = IAdapter(info.meta[3]);
        IERC20 baseToken = IERC20(info.path[info.path.length - 1]);

        //handle Pool swap
        IPool pool = IPool(info.meta[0]);

        //swap ETH to base token
        uint256[] memory amounts = adapter.getAmountsOut(msg.value, info.path);
        uint256 baseAmountOutSansFee = adapter.swapExactETHForTokens{
            value: msg.value
        }(amounts[info.path.length - 1], info.path, address(this));

        //deduct fees
        (uint256 dataxFee, uint256 refFee) = calcFees(
            baseAmountOutSansFee,
            STAKE_FEE_TYPE,
            info.uints[1]
        );
        //collect ref Fees
        if (info.meta[2] != address(0)) {
            referralFees[info.meta[2]][address(baseToken)] = referralFees[
                info.meta[2]
            ][address(baseToken)].add(refFee);
            //datax fee
            referralFees[admin][address(baseToken)] = referralFees[admin][
                address(baseToken)
            ].add(dataxFee);
        } else {
            referralFees[admin][address(baseToken)] = referralFees[admin][
                address(baseToken)
            ].add(badd(dataxFee, refFee));
        }

        // actual base amount minus fees
        uint256 baseAmountOut = bsub(
            baseAmountOutSansFee,
            badd(dataxFee, refFee)
        );
        //approve Pool to spend base token
        baseToken.safeApprove(address(pool), baseAmountOut);

        //stake tokens in Pool
        poolTokensOut = pool.joinswapExternAmountIn(
            baseAmountOut,
            info.uints[2]
        );

        //transfer pool tokens to destination address
        IERC20(info.meta[0]).safeTransfer(info.meta[1], poolTokensOut);

        emit StakedETHInPool(
            info.meta[0],
            info.meta[1],
            info.meta[2],
            msg.value,
            baseAmountOut
        );
    }

    function unstakeETHFromDTPool(StakeInfo calldata info)
        external
        nonReentrant
        returns (uint256 ethAmountOut)
    {
        require(
            info.meta[2] != address(0),
            "StakeRouter: Destination address not provided"
        );

        require(
            info.uints[0] <=
                IERC20(info.meta[0]).allowance(msg.sender, address(this)),
            "StakeRouter: Not enough token allowance"
        );

        require(info.path.length > 1, "StakeRouter: Path too short");

        IERC20 baseToken = IERC20(info.path[0]);
        //unstake into baseToken
        IPool pool = IPool(info.meta[0]);
        IERC20(info.meta[0]).safeTransferFrom(
            msg.sender,
            address(this),
            info.uints[0]
        );
        IERC20(info.meta[0]).safeApprove(address(pool), info.uints[0]);

        //unstake baseToken from Pool
        uint256 baseAmountOutSansFee = pool.exitswapPoolAmountIn(
            info.uints[0],
            info.uints[2]
        );

        //deduct fees
        (uint256 dataxFee, uint256 refFee) = calcFees(
            baseAmountOutSansFee,
            UNSTAKE_FEE_TYPE,
            info.uints[1]
        );
        //collect ref Fees
        if (info.meta[2] != address(0)) {
            referralFees[info.meta[2]][address(baseToken)] = referralFees[
                info.meta[2]
            ][address(baseToken)].add(refFee);
            //datax fee
            referralFees[admin][address(baseToken)] = referralFees[admin][
                address(baseToken)
            ].add(dataxFee);
        } else {
            referralFees[admin][address(baseToken)] = referralFees[admin][
                address(baseToken)
            ].add(badd(dataxFee, refFee));
        }
        // actual base amount minus fees
        uint256 baseAmountOut = bsub(
            baseAmountOutSansFee,
            badd(dataxFee, refFee)
        );

        baseToken.safeApprove(info.meta[3], baseAmountOut);

        //swap to output token
        IAdapter adapter = IAdapter(info.meta[3]);
        //swap basetoken to ETH
        uint256[] memory amounts = adapter.getAmountsOut(
            baseAmountOut,
            info.path
        );
        ethAmountOut = adapter.swapExactTokensForETH(
            baseAmountOut,
            amounts[info.path.length - 1],
            info.path,
            info.meta[1]
        );

        emit UnstakedETHFromPool(
            info.meta[0],
            info.meta[1],
            info.meta[2],
            ethAmountOut,
            baseAmountOut
        );
    }

    function stakeTokenInDTPool(StakeInfo calldata info)
        external
        nonReentrant
        returns (uint256 poolTokensOut)
    {
        require(
            info.meta[2] != address(0),
            "StakeRouter: Destination address not provided"
        );

        require(
            info.uints[0] <=
                IERC20(info.path[0]).allowance(msg.sender, address(this)),
            "StakeRouter: Not enough token allowance"
        );

        IERC20 baseToken = IERC20(info.path[info.path.length - 1]);
        uint256 baseAmountOutSansFee = info.uints[0];

        require(
            IERC20(info.path[0]).balanceOf(msg.sender) >= info.uints[0],
            "StakeRouter: Not enough tokenIn balance"
        );
        IERC20(info.path[0]).safeTransferFrom(
            msg.sender,
            address(this),
            info.uints[0]
        );

        //skip if tokenIn is baseToken
        if (info.path.length > 1) {
            IAdapter adapter = IAdapter(info.meta[3]);
            uint256[] memory amounts = adapter.getAmountsOut(
                info.uints[0],
                info.path
            );

            IERC20(info.path[0]).safeApprove(info.meta[3], info.uints[0]);
            baseAmountOutSansFee = adapter.swapExactTokensForTokens(
                info.uints[0],
                amounts[info.path.length - 1],
                info.path,
                address(this)
            );
        }

        //deduct fees
        (uint256 dataxFee, uint256 refFee) = calcFees(
            baseAmountOutSansFee,
            STAKE_FEE_TYPE,
            info.uints[1]
        );
        //collect ref Fees
        if (info.meta[2] != address(0)) {
            referralFees[info.meta[2]][address(baseToken)] = referralFees[
                info.meta[2]
            ][address(baseToken)].add(refFee);
            //datax fee
            referralFees[admin][address(baseToken)] = referralFees[admin][
                address(baseToken)
            ].add(dataxFee);
        } else {
            referralFees[admin][address(baseToken)] = referralFees[admin][
                address(baseToken)
            ].add(badd(dataxFee, refFee));
        }
        // actual base amount minus fees
        uint256 baseAmountOut = bsub(
            baseAmountOutSansFee,
            badd(dataxFee, refFee)
        );

        //handle Pool swap
        IPool pool = IPool(info.meta[0]);
        //approve Pool to spend base token
        baseToken.safeApprove(info.meta[0], baseAmountOut);

        //stake tokens in Pool
        poolTokensOut = pool.joinswapExternAmountIn(
            baseAmountOut,
            info.uints[2]
        );

        //transfer pool tokens to destination address
        IERC20(info.meta[0]).safeTransfer(info.meta[1], poolTokensOut);

        emit StakedTokenInPool(
            info.meta[0],
            info.path[0],
            info.meta[1],
            info.meta[2],
            info.uints[0],
            baseAmountOut
        );
    }

    function unstakeTokenFromDTPool(StakeInfo calldata info)
        external
        nonReentrant
        returns (uint256 tokenAmountOut)
    {
        require(
            info.meta[2] != address(0),
            "StakeRouter: Destination address not provided"
        );

        require(
            info.uints[0] <=
                IERC20(info.meta[0]).allowance(msg.sender, address(this)),
            "StakeRouter: Not enough token allowance"
        );

        //unstake into baseToken
        IPool pool = IPool(info.meta[0]);
        IERC20(info.meta[0]).safeTransferFrom(
            msg.sender,
            address(this),
            info.uints[0]
        );
        IERC20(info.meta[0]).safeApprove(address(pool), info.uints[0]);

        //unstake baseToken from Pool
        uint256 baseAmountOutSansFee = pool.exitswapPoolAmountIn(
            info.uints[0],
            info.uints[2]
        );

        IERC20 baseToken = IERC20(info.path[0]);

        //deduct fees
        (uint256 dataxFee, uint256 refFee) = calcFees(
            baseAmountOutSansFee,
            UNSTAKE_FEE_TYPE,
            info.uints[1]
        );
        //collect ref Fees
        if (info.meta[2] != address(0)) {
            referralFees[info.meta[2]][address(baseToken)] = referralFees[
                info.meta[2]
            ][address(baseToken)].add(refFee);
            //datax fee
            referralFees[admin][address(baseToken)] = referralFees[admin][
                address(baseToken)
            ].add(dataxFee);
        } else {
            referralFees[admin][address(baseToken)] = referralFees[admin][
                address(baseToken)
            ].add(badd(dataxFee, refFee));
        }
        // actual base amount minus fees
        uint256 baseAmountOut = bsub(
            baseAmountOutSansFee,
            badd(dataxFee, refFee)
        );

        //skip if tokenOut is the baseToken
        if (info.path.length > 1) {
            baseToken.safeApprove(info.meta[3], baseAmountOut);
            //swap to output token
            IAdapter adapter = IAdapter(info.meta[3]);
            //swap basetoken to Destination token
            uint256[] memory amounts = adapter.getAmountsOut(
                baseAmountOut,
                info.path
            );
            tokenAmountOut = adapter.swapExactTokensForTokens(
                baseAmountOut,
                amounts[info.path.length - 1],
                info.path,
                info.meta[1]
            );
        } else {
            //send tokenOut to destination address
            baseToken.safeTransfer(info.meta[1], baseAmountOut);
        }

        emit UnstakedTokenFromPool(
            info.meta[0],
            info.path[0],
            info.meta[1],
            info.meta[2],
            info.uints[0],
            baseAmountOut
        );
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

        (dataxFee, refFee) = calcFees(amountIn, STAKE_FEE_TYPE, info.uints[1]);
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

        (dataxFee, refFee) = calcFees(amountOut, STAKE_FEE_TYPE, info.uints[1]);
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

        (dataxFee, refFee) = calcFees(
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
