pragma solidity >=0.8.0 <0.9.0;

//Copyright of DataX Protocol contributors
//SPDX-License-Identifier: BSU-1.1

interface ICommunityFeeCollector {
    function withdrawETH() external payable;

    function withdrawToken(address tokenAddress) external;

    function changeCollector(address payable newCollector) external;

    fallback() external payable;

    /**
     * @dev receive ETH
     */
    receive() external payable;
}
