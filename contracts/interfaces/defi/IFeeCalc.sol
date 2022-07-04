pragma solidity >=0.8.0 <0.9.0;

//SPDX-License-Identifier: BSU-1.1

interface IFeeCalc {
    function calcFees(
        uint256 baseAmount,
        string memory feeType,
        uint256 refFeeRate
    ) external view returns (uint256 dataxFee, uint256 refFee);
}
