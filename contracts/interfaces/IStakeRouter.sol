// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
// for fetching details about the dataTokens and baseTokens .

interface IStakeRouter  {


/* get current version of the contract
*/
function getCurrentVersion() external returns(uint);



/** setting the new collector for the fees.

 */

function setCollector(address _newCollector) external returns(uint);

/** allows to set any of the parmeters present in the getter functions for the contract (state , staking , unstaking , current version)  
@param key is the key value corresponding to the parameter that you want to set : its set by keccak256("parameterName", currentVersion);
@param  value  is the new value of the state parameter.
@param paramName is string representation of the parameter name.
 */
function setParamUint( string paramName   , uint256 value  )  external;

/** takes  the  token amount from any supported ERC20 <> DT lp pair and stakes it to the base pair.
@param dtpoolAddress address of dtpool where user wants to stake token 
@param tokenAmountsOut is the amount of exact dataToken that you want to be staked in the balancer pool (excl the fees).
@param path is the array of the address array for swap from the given user input token <> underlying DT <> baseToken.
@param datatoken is the address of the datatoken (H20/OCEAN) that you want to stake in datapool.
@param deadline is the  max timeline in which the order must be filled .
@param refStakingAddress consist of  the address of the collector contract of the third party service provider.
@param refStakingFees is the fee value that we extract from the provider 
 */

function StakeERC20toDT(address dtpoolAddress, uint256 tokenAmountsOut, address[] calldata path , address datatoken,  uint256 deadline, address refStakingAddress, uint256 refStakingFees ) payable external ;

/**  takes the given amount of ETH from user and stakes into the corresponding basetoken datapool 
@param amountDTOut is the  dataTokens that you want to stake finally in pool.
@param path stores the address in array followed by the swap and stake operation .
@param refStakingAddress is the address of the third party that will be paying the fees
@param refStakingFees is the fees being extracted by the specific address for the staking operation.
 */

function StakeETHtoDT(address dtpoolAddress, uint256 amountDTOut, address[] calldata path, address datatoken, uint256 deadline, address refStakingAddress, uint256 refStakingFees ) payable  external ;

/** allows to stake any data token holded by the user into the specific basetoken of the given pools hosted by dataX.
@param dtpoolAddress address of datapool
@param amountDTOut defines  the  amount of the staked basedtoken of the pool .
@param amountDTMaxIn defines the max amount of the input datatokens that you want to  swap
@param path is the array  of addresses followed by swap and stake operation according to the available  liquidity 
@param deadline transaction deadline
@param refStakingAddress is the address of the third party that will be paying the fees
@param refStakingFees is the fees being extracted from the specific address for the staking operation.
*/
function StakeDTtoDT(address dtpoolAddress, uint256 amountDTOut, uint256 amountDTMaxIn,  address[] calldata  path ,uint256 deadline,  address refStakingAddress , uint256 refStakingFees) payable  external;


/** allows to unstake the baseToken from the given dataPools and return the user the given ERC20 token 
@param dtpoolAddress is the address of the dataPool in which user wants to unstake DT.
@param poolAmountIn  is the amount of   the dataToken that user wants to unstake.  
@param amountOutMin  is the min amount of resulting unstaked  baseToken  that user wants to return. 
@param datatoken is the address to the datatoken.
@param path is the array  of addresses followed by swap and stake operation according to the available  liquidity 
@param to is the destination address which will receive corresponding unstaked rewards after unstaking and swap.
@param refUnstakingAddress  is the address of the third party that will be paying the fees for unstaking.
@param refUnstakingFees is the fees being extracted from the specific address for the Unstaking operation.
@param deadline is the timestemp before which the txn with amountOutMin should be transactioned.
 */

function UnstakeDTtoERC20(address dtpoolAddress, uint256 poolAmountIn, uint256 amountOutMin, address datatoken ,address[] calldata  path ,uint256 deadline , address to, address refUnstakingAddress , uint256 refUnstakingFees ) payable  external;


/** allows to unstake the DT (Data/H20) from the given dataPools and return the user in the resulting ETH

@param dtpoolAddress is the address of datapool token that you want to  unstake from .
@param   poolAmountIn is the amount of the BaseTokens that you want to unstake to  ETH 
@param  amountOutMin is the corresponding  amount of the minimum  baseTokens  tokens that user wants.
@param path is the array  of addresses followed by swap and stake operation according to the available  liquidity 
@param to is the destination address receiving the given swapped tokens .
@param refUnstakingAddress  is the address of the third party that will be paying the fees for unstaking.
@param refUnstakingFees is the fees being extracted from the specific address for the Unstaking operation.
@param deadline is the timestemp before which the txn with amountOutMin should be swapped as result.
*/
function UnstakeDTtoETH(address dtpoolAddress, uint256 poolAmountIn, uint256 amountOutMin , address[] calldata  path ,uint256 deadline address to, uint256 deadline,   address refUnstakingAddress , uint256 refUnstakingFees ) payable  external;

/** allows unstaking of the DT from datapool (ocean/H20) to other dataTokens .
@param dtpoolAddress is the address of datapool token that you want to  develop.
@param   poolAmountIn is the amount of the BaseTokens that you want to unstake to  ETH. 
@param  amountOutMin is the corresponding  amount of the minimum  baseTokens  tokens that user wants.
@param path is the array  of addresses followed by swap and stake operation according to the available  liquidity .
@param deadline deadline is the timestemp before which the txn with amountOutMin should be transactioned
@param refUnstakingAddress is the address of the  third party that will be paying the fees for unstaking.
@param refUnstakingFees is the fees being extracted from the specific address for the Unstaking operation.
@param deadline is the timestemp before which the txn with amountOutMin should be swapped as result.
*/
function UnstakeDTtoDT(address dtpoolAddress, uint256 poolAmountIn, uint256 amountOutMin, address[] calldata  path , uint256 deadline,  address refUnstakingAddress , uint256 refUnstakingFees ) payable  external;




}
