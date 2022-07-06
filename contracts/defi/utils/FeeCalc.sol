pragma solidity >=0.8.0 <0.9.0;

//Copyright of DataX Protocol contributors
//SPDX-License-Identifier: BSU-1.1

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./FeeAdmin.sol";
import "./Math.sol";
import "./Admin.sol";
import "hardhat/console.sol";

contract FeeCalc is Math {
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
        console.log("WE are OKAY");
        // DataX Fees
        if (feeRate != 0) {
            dataxFee = bsub(
                baseAmount,
                (bmul(baseAmount, (bsub(BONE, feeRate))))
            );
            console.log("WE managed DATAX fees");
        }
        // Referral fees
        if (refFeeRate != 0) {
            refFee = bsub(
                baseAmount,
                (bmul(baseAmount, (bsub(BONE, refFeeRate))))
            );
            console.log("WE managed REF fees");
        }
        console.log("WE are all good");
    }
}
