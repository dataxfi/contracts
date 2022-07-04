pragma solidity >=0.8.0 <0.9.0;
//Copyright of DataX Protocol contributors
//SPDX-License-Identifier: BSU-1.1

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../utils/Admin.sol";
import "../utils/Const.sol";
import "../../interfaces/defi/IAdapter.sol";
import "../../interfaces/defi/IFeeCalc.sol";
import "../../interfaces/ocean/IPool.sol";

contract StakeRouter is ReentrancyGuard, Const, Admin {
    IFeeCalc fees;
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    mapping(address => mapping(address => uint256)) public referralFees;

    struct StakeInfo {
        address[4] meta; //[pool, to, refAddress, adapterAddress]
        uint256[3] uints; //[amountIn/maxAmountIn, refFees, amountOut/minAmountOut]
        address[] path;
    }

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

    constructor(address _feeCalc) {
        fees = IFeeCalc(_feeCalc);
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
        (uint256 dataxFee, uint256 refFee) = fees.calcFees(
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
            ].add(dataxFee.add(refFee));
        }

        // actual base amount minus fees
        uint256 baseAmountOut = baseAmountOutSansFee.sub(dataxFee.add(refFee));
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
        (uint256 dataxFee, uint256 refFee) = fees.calcFees(
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
            ].add(dataxFee.add(refFee));
        }
        // actual base amount minus fees
        uint256 baseAmountOut = baseAmountOutSansFee.sub(dataxFee.add(refFee));

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
        (uint256 dataxFee, uint256 refFee) = fees.calcFees(
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
            ].add(dataxFee.add(refFee));
        }
        // actual base amount minus fees
        uint256 baseAmountOut = baseAmountOutSansFee.sub(dataxFee.add(refFee));

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
        (uint256 dataxFee, uint256 refFee) = fees.calcFees(
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
            ].add(dataxFee.add(refFee));
        }
        // actual base amount minus fees
        uint256 baseAmountOut = baseAmountOutSansFee.sub(dataxFee.add(refFee));

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
