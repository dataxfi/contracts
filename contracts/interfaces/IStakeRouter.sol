pragma solidity  >=0.8.0 <0.9.0;
// SPDX-License-Identifier: BSU-1.1

/** @notice : interface to stake any erc20 token in datapools
 */
interface IStakeRouter  {

/********* ETH ************/

    /** @dev stakes ETH (native token) into datapool
     */
    function stakeETHInPool(TradeInfo info) external payable  returns (uint256 poolAmountOut){

    /** @dev unstakes staked pool tokens into ETH from datapool
     */
    function unstakeToETHFromPool(TradeInfo info) external returns (uint256 amountOut);

    /********* ERC20 ************/

   /** @dev stakes given Erc20 token into datapool
     */
    function stakeTokenInPool(TradeInfo info) external payable  returns (uint256 poolAmountOut){

    /** @dev unstakes staked pool tokens into given Erc20 from datapool
     */
    function unstakeToTokenFromPool(TradeInfo info) external returns (uint256 amountOut);


    /********* DT ************/ 

    /** @dev stakes given DT into given datapool
     */
    function stakeDTInPool(TradeInfo info) external payable  returns (uint256 poolAmountOut){

    /** @dev unstakes staked pool tokens into given DT from given datapool
     */
    function unstakeDTFromPool(TradeInfo info) external returns (uint256 amountOut);



}
