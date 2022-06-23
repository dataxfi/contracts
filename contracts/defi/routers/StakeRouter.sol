pragma solidity >=0.8.0 <0.9.0;
//Copyright of DataX Protocol contributors
//SPDX-License-Identifier: BSU-1.1

import "../../interfaces/defi/IAdapter.sol";
import "../../interfaces/ocean/IPool.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../../interfaces/defi/IStorage.sol";
import "../utils/Math.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract StakeRouter is ReentrancyGuard, Math {
    using SafeMath for uint256;
    IStorage store;
    uint8 public version;
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
        uint256[3] uints; //[amountOut/minAmountOut, refFees, amountIn/maxAmountIn]
        address[] path;
    }

    constructor(uint8 _version, address _storage) {
        version = _version;
        store = IStorage(_storage);
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
        }

        // actual base amount minus fees
        uint256 baseAmountOut = bsub(
            baseAmountOutSansFee,
            badd(dataxFee, refFee)
        );
        //approve Pool to spend base token
        require(
            baseToken.approve(address(pool), baseAmountOut),
            "StakeRouter: Failed to approve Basetoken on Pool"
        );

        //stake tokens in Pool
        poolTokensOut = pool.joinswapExternAmountIn(
            baseAmountOut,
            info.uints[0]
        );

        //transfer pool tokens to destination address
        require(
            IERC20(info.meta[0]).transfer(info.meta[1], poolTokensOut),
            "StakeRouter: Pool Token transfer failed"
        );

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
            info.uints[2] <=
                IERC20(info.meta[0]).allowance(msg.sender, address(this)),
            "StakeRouter: Not enough token allowance"
        );

        require(info.path.length > 1, "StakeRouter: Path too short");

        IERC20 baseToken = IERC20(info.path[0]);
        //unstake into baseToken
        IPool pool = IPool(info.meta[0]);
        IERC20(info.meta[0]).transferFrom(
            msg.sender,
            address(this),
            info.uints[2]
        );
        IERC20(info.meta[0]).approve(address(pool), info.uints[2]);

        //unstake baseToken from Pool
        uint256 baseAmountOutSansFee = pool.exitswapPoolAmountIn(
            info.uints[2],
            info.uints[0]
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
        }
        // actual base amount minus fees
        uint256 baseAmountOut = bsub(
            baseAmountOutSansFee,
            badd(dataxFee, refFee)
        );

        baseToken.approve(info.meta[3], baseAmountOut);

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
            info.uints[2] <=
                IERC20(info.path[0]).allowance(msg.sender, address(this)),
            "StakeRouter: Not enough token allowance"
        );

        IERC20 baseToken = IERC20(info.path[info.path.length - 1]);
        uint256 baseAmountOutSansFee = info.uints[2];

        require(
            IERC20(info.path[0]).balanceOf(msg.sender) >= info.uints[2],
            "StakeRouter: Not enough tokenIn balance"
        );
        IERC20(info.path[0]).transferFrom(
            msg.sender,
            address(this),
            info.uints[2]
        );

        //skip if tokenIn is baseToken
        if (info.path.length > 1) {
            IAdapter adapter = IAdapter(info.meta[3]);
            uint256[] memory amounts = adapter.getAmountsOut(
                info.uints[2],
                info.path
            );

            IERC20(info.path[0]).approve(info.meta[3], info.uints[2]);
            baseAmountOutSansFee = adapter.swapExactTokensForTokens(
                info.uints[2],
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
        }
        // actual base amount minus fees
        uint256 baseAmountOut = bsub(
            baseAmountOutSansFee,
            badd(dataxFee, refFee)
        );

        //handle Pool swap
        IPool pool = IPool(info.meta[0]);
        //approve Pool to spend base token
        require(
            baseToken.approve(info.meta[0], baseAmountOut),
            "StakeRouter: Failed to approve Basetoken on Pool"
        );

        //stake tokens in Pool
        poolTokensOut = pool.joinswapExternAmountIn(
            baseAmountOut,
            info.uints[0]
        );

        //transfer pool tokens to destination address
        require(
            IERC20(info.meta[0]).transfer(info.meta[1], poolTokensOut),
            "Error: Pool Token transfer failed"
        );

        emit StakedTokenInPool(
            info.meta[0],
            info.path[0],
            info.meta[1],
            info.meta[2],
            info.uints[2],
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
            info.uints[2] <=
                IERC20(info.meta[0]).allowance(msg.sender, address(this)),
            "StakeRouter: Not enough token allowance"
        );

        //unstake into baseToken
        IPool pool = IPool(info.meta[0]);
        IERC20(info.meta[0]).transferFrom(
            msg.sender,
            address(this),
            info.uints[2]
        );
        IERC20(info.meta[0]).approve(address(pool), info.uints[2]);

        //unstake baseToken from Pool
        uint256 baseAmountOutSansFee = pool.exitswapPoolAmountIn(
            info.uints[2],
            info.uints[0]
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
        }
        // actual base amount minus fees
        uint256 baseAmountOut = bsub(
            baseAmountOutSansFee,
            badd(dataxFee, refFee)
        );

        //skip if tokenOut is the baseToken
        if (info.path.length > 1) {
            baseToken.approve(info.meta[3], baseAmountOut);
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
            require(
                baseToken.transfer(info.meta[1], baseAmountOut),
                "StakeRouter: Failed to transfer tokenOut"
            );
        }

        emit UnstakedTokenFromPool(
            info.meta[0],
            info.path[0],
            info.meta[1],
            info.meta[2],
            info.uints[2],
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
        uint256 amountIn = info.uints[2];

        //skip if tokenOut is the baseToken
        if (info.path.length > 1) {
            IAdapter adapter = IAdapter(info.meta[3]);
            uint256[] memory amounts = adapter.getAmountsOut(
                info.uints[2],
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
        uint256 amountOut = info.uints[0];

        //skip if tokenOut is the baseToken
        if (info.path.length > 1) {
            IAdapter adapter = IAdapter(info.meta[3]);
            uint256[] memory amounts = adapter.getAmountsIn(
                info.uints[0],
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
            info.uints[2]
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

    //calculate fees
    function calcFees(
        uint256 baseAmount,
        string memory feeType,
        uint256 refFeeRate
    ) public view returns (uint256 dataxFee, uint256 refFee) {
        uint256 feeRate = store.getFees(feeType);
        require(
            refFeeRate <= bsub(BONE, feeRate),
            "StakeRouter: Ref Fees too high"
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
        require(
            baseToken.transfer(referrer, claimAmount),
            "StakeRouter: Referral Token claim failed"
        );

        emit ReferralFeesClaimed(referrer, token, claimAmount);
    }

    //receive ETH
    receive() external payable {}
}
