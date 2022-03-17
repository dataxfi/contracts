// SPDX-Iicense-Identifier: MIT

pragma solidity ^0.8.10;

interface ICommunityFeeCollector {


function withdrawETH() external payable ;

function withdrawToken(address tokenAddress) external;


function changeCollector(address payable newCollector) external ;


fallback() external payable ;

    /**
     * @dev receive ETH
     */
receive() external payable ;





}