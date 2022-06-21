pragma solidity >=0.8.0 <0.9.0;

// SPDX-License-Identifier: BSU-1.1

struct StakeInfo {
    address[4] meta; //[pool, to, refAddress, adapterAddress]
    uint256[3] uints; //[amountOut/minAmountOut, refFees, amountIn/maxAmountIn]
    address[] path;
}

/** @notice : interface to stake any erc20 token in datapools
 */
interface IStakeRouter {
    /********* ETH ************/

    /** @dev stakes ETH (native token) into datapool
     */
    function stakeETHInPool(StakeInfo calldata info)
        external
        payable
        returns (uint256 poolAmountOut);

    /** @dev unstakes staked pool tokens into ETH from datapool
     */
    function unstakeToETHFromPool(StakeInfo calldata info)
        external
        returns (uint256 amountOut);

    /********* ERC20 ************/

    /** @dev stakes given Erc20 token into datapool
     */
    function stakeTokenInPool(StakeInfo calldata info)
        external
        payable
        returns (uint256 poolAmountOut);

    /** @dev unstakes staked pool tokens into given Erc20 from datapool
     */
    function unstakeToTokenFromPool(StakeInfo calldata info)
        external
        returns (uint256 amountOut);

    /********* DT ************/

    /** @dev stakes given DT into given datapool
     */
    function stakeDTInPool(StakeInfo calldata info)
        external
        payable
        returns (uint256 poolAmountOut);

    /** @dev unstakes staked pool tokens into given DT from given datapool
     */
    function unstakeDTFromPool(StakeInfo calldata info)
        external
        returns (uint256 amountOut);
}
