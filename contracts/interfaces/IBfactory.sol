//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;


interface IBFactory {

  /**
     * @dev isOceanToken
     *      Returns true if token exists in the list of tokens with reduced fees
     *  @param oceanTokenAddress address Token to be checked
     */
    function isOceanToken(address oceanTokenAddress) external view returns(bool);


 /**
     * @dev getOceanTokens
     *      Returns the list of tokens with reduced fees
     to be used by the stakeRouter and TradeRouter address to find the fees for the 
     */
    function getOceanTokens() external view returns(address[] memory) ;


     /**
     * @dev isSSContract
     *      Returns true if token exists in the list of ssContracts
     *  @param _ssContract  address Contract to be checked
     */
    function isSSContract(address _ssContract) external view returns(bool);
    /**
     * @dev getOPCFee
     *      Gets OP Community Fees for a particular token
     * @param baseToken  address token to be checked
     */
    function getOPCFee(address baseToken) external view returns (uint256) ;


      /**
     * @dev Deploys a new `OceanPool` on Ocean Friendly Fork modified for 1SS.
     This function cannot be called directly, but ONLY through the ERC20DT contract from a ERC20DEployer role

      ssContract address
     tokens [datatokenAddress, baseTokenAddress]
     publisherAddress user which will be assigned the vested amount.
     * @param tokens precreated parameter
     * @param ssParams params for the ssContract. 
     *                     [0]  = rate (wei)
     *                     [1]  = baseToken decimals
     *                     [2]  = vesting amount (wei)
     *                     [3]  = vested blocks
     *                     [4]  = initial liquidity in baseToken for pool creation
     * @param swapFees swapFees (swapFee, swapMarketFee), swapOceanFee will be set automatically later
     *                     [0] = swapFee for LP Providers
     *                     [1] = swapFee for marketplace runner
      
      .
     * @param addresses refers to an array of addresses passed by user
     *                     [0]  = side staking contract address
     *                     [1]  = baseToken address for pool creation(OCEAN or other)
     *                     [2]  = baseTokenSender user which will provide the baseToken amount for initial liquidity
     *                     [3]  = publisherAddress user which will be assigned the vested amount
     *                     [4]  = marketFeeCollector marketFeeCollector address
                           [5]  = poolTemplateAddress
       
        @return pool address
     */


    // [datatokenAddress, baseTokenAddress]
     function deployPool(
     address[2] calldata tokens,
        uint256[] calldata ssParams,
        uint256[] calldata swapFees,
        address[] calldata addresses
    )
        external returns(address pool);

}

