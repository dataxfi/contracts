pragma solidity >=0.8.0 <0.9.0;

//Copyright of DataX Protocol contributors
//SPDX-License-Identifier: BSU-1.1

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./FeeAdmin.sol";
import "./Const.sol";
import "./Admin.sol";

contract FeeCalc is Const {
    FeeAdmin fee;
    using SafeMath for uint256;

    constructor(address _feeAdmin) {
        fee = FeeAdmin(_feeAdmin);
    }

    function calcFees(
        uint256 baseAmount,
        string memory feeType,
        uint256 refFeeRate
    ) public view returns (uint256 dataxFee, uint256 refFee) {
        uint256 feeRate = fee.getFees(feeType);
        require(refFeeRate <= BONE.sub(feeRate), "Fee: Ref Fees too high");

        // DataX Fees
        if (feeRate != 0) {
            dataxFee = baseAmount.sub(baseAmount.mul(BONE.sub(feeRate)));
        }
        // Referral fees
        if (refFeeRate != 0) {
            refFee = baseAmount.sub(baseAmount.mul(BONE.sub(refFeeRate)));
        }
    }
}
