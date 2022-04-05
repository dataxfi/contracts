pragma solidity >=0.8.0 <0.9.0;
//Copyright of DataX Protocol contributors
//SPDX-License-Identifier: BSU-1.1

import "../interfaces/IUniV2Adapter.sol";
import "../interfaces/IStakeRouter.sol";
import "../interfaces/ICommunityFeeCollector.sol";
import "../interfaces/IPool.sol";
import "../interfaces/IFixedRateExchange.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract StakeRouter is ReentrancyGuard {
    using SafeMath for uint256;
    ICommunityFeeCollector collector;
    uint256 public currentVersion;
    uint256 MAX_INT = 2**256 - 1;

    constructor(uint256 _version) {
        currentVersion = _version;
    }

    function StakeETH(
        uint256[4] calldata uints, //[quoteAmountOut, refFees, deadline]
        address[] calldata path,
        address[5] calldata meta //[pool, tokenInAddress, to, refAddress, adapterAddress]
    ) external payable returns (uint256 amountIn) {
        require(meta[2] != address(0), "Destination address not provided");

        //swap ETH to dtpool quote token
        IUniV2Adapter adapter = IUniV2Adapter(meta[4]);

        uint256[] memory _amounts = adapter.swapExactETHForTokens{
            value: msg.value
        }(uints[0], path, address(this), uints[3]);

        IERC20 token = IERC20(path[path.length - 1]);

        //handle Pool swap
        IPool pool = IPool(meta[0]);

        //approve Pool to spend base token
        require(
            token.approve(address(pool), _amounts[_amounts.length - 1]),
            "Error: Failed to approve Pool"
        );

        //stake base token into pool
        uint256 poolAmountOut = pool.joinswapExternAmountIn(
            _amounts[_amounts.length - 1],
            0
        );

        //transfer pool tokens to destination address
        require(
            pool.transfer(meta[2], poolAmountOut),
            "Error: PoolTokens transfer failed"
        );
    }

    function StakeTokens(
        uint256[4] calldata uints, //[tokenInAmount, refFees, deadline]
        address[] calldata path,
        address[5] calldata meta //[pool, tokenInAddress, to, refAddress, adapterAddress]
    ) external returns (uint256 amountIn) {
        require(meta[2] != address(0), "Destination address not provided");

        //swap Tokens to dtpool quote token
        IUniV2Adapter adapter = IUniV2Adapter(meta[4]);

        uint256[] memory _amounts = adapter.swapExactTokensForTokens{
            value: msg.value
        }(uints[0], path, address(this), uints[3]);

        IERC20 token = IERC20(path[path.length - 1]);

        //handle Pool swap
        IPool pool = IPool(meta[0]);

        //approve Pool to spend base token
        require(
            token.approve(address(pool), _amounts[_amounts.length - 1]),
            "Error: Failed to approve Pool"
        );

        //stake base token into pool
        uint256 poolAmountOut = pool.joinswapExternAmountIn(
            _amounts[_amounts.length - 1],
            0
        );

        //transfer pool tokens to destination address
        require(
            pool.transfer(meta[2], poolAmountOut),
            "Error: PoolTokens transfer failed"
        );
    }

    function UnstakeToETH(
        uint256[4] calldata uints, //[poolAmountIn, minTokenAmountOut, refFees, deadline]
        address[] calldata path,
        address[5] calldata meta //[pool, tokenInAddress, to, refAddress, adapterAddress]
    ) external payable returns (uint256 amountIn) {
        require(meta[2] != address(0), "Destination address not provided");

        IERC20 token = IERC20(pool);

        //approve Pool to spend base token
        require(
            token.allowance(address(this)) > uints[0],
            "Error: Not enough allowance"
        );

        //unstake base token from pool
        uint256 tokenAmountOut = pool.exitswapPoolAmountIn(uints[0], uints[1]);

        //swap base token to ETH
        IUniV2Adapter adapter = IUniV2Adapter(meta[4]);

        uint256[] memory _amounts = adapter.swapExactTokensForETH(
            tokenAmountOut,
            0,
            path,
            address(this),
            uints[3]
        );

        //transfer ETH to user
        (bool sent, ) = payable(to).call{value: _amounts[_amounts.length - 1]}(
            ""
        );
        require(sent, "Error: ETH transfer failed");
    }

    function UnstakeToToken(
        uint256[4] calldata uints, //[poolAmountIn, minTokenAmountOut, refFees, deadline]
        address[] calldata path,
        address[5] calldata meta //[pool, tokenInAddress, to, refAddress, adapterAddress]
    ) external payable returns (uint256 amountIn) {
        require(meta[2] != address(0), "Destination address not provided");

        IERC20 token = IERC20(pool);

        //approve Pool to spend base token
        require(
            token.allowance(address(this)) > uints[0],
            "Error: Not enough allowance"
        );

        //unstake base token from pool
        uint256 tokenAmountOut = pool.exitswapPoolAmountIn(uints[0], uints[1]);

        //swap base token to ETH
        IUniV2Adapter adapter = IUniV2Adapter(meta[4]);

        uint256[] memory _amounts = adapter.swapExactTokensForTokens(
            tokenAmountOut,
            0,
            path,
            address(this),
            uints[3]
        );

        //transfer output token to destination address
        require(
            IERC20(path[path.length - 1]).transfer(
                meta[2],
                _amounts[_amounts.length - 1]
            ),
            "Error: Token transfer failed"
        );
    }

    //receive ETH
    receive() external payable {}
}
