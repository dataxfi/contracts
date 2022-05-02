//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface IFactory {
    /**
     * @dev isOceanToken
     *      Returns true if token exists in the list of tokens with reduced fees
     *  @param oceanTokenAddress address Token to be checked
     */
    function isOceanToken(address oceanTokenAddress)
        external
        view
        returns (bool);

    /**
     * @dev getOceanTokens
     *      Returns the list of tokens with reduced fees
     to be used by the stakeRouter and TradeRouter address to find the fees for the 
     */
    function getOceanTokens() external view returns (address[] memory);

    /**
     * @dev isSSContract
     *      Returns true if token exists in the list of ssContracts
     *  @param _ssContract  address Contract to be checked
     */
    function isSSContract(address _ssContract) external view returns (bool);

    /**
     * @dev getOPCFee
     *      Gets OP Community Fees for a particular token
     * @param baseToken  address token to be checked
     */
    function getOPCFee(address baseToken) external view returns (uint256);
}
