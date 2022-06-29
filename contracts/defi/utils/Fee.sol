pragma solidity >=0.8.0 <0.9.0;

//Copyright of DataX Protocol contributors
//SPDX-License-Identifier: BSU-1.1

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./Math.sol";
import "./Admin.sol";

contract Fee is ReentrancyGuard, Math, Admin {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    mapping(bytes32 => uint256) public fees;

    constructor() {
        admin = msg.sender;
    }

    function calcFees(
        uint256 baseAmount,
        string memory feeType,
        uint256 refFeeRate
    ) public view returns (uint256 dataxFee, uint256 refFee) {
        uint256 feeRate = getFees(feeType);
        require(refFeeRate <= bsub(BONE, feeRate), "Fee: Ref Fees too high");

        // DataX Fees
        if (feeRate != 0) {
            dataxFee = bsub(baseAmount, bmul(baseAmount, bsub(BONE, feeRate)));
        }
        // Referral fees
        if (refFeeRate != 0) {
            refFee = bsub(baseAmount, bmul(baseAmount, bsub(BONE, refFeeRate)));
        }
    }

    function withdrawToken(address tokenAddress, uint256 amount)
        external
        adminOnly
    {
        require(
            tokenAddress != address(0),
            "Fee: invalid token contract address"
        );

        IERC20(tokenAddress).safeTransfer(admin, amount);
    }

    function withdrawETH(uint256 amount) external adminOnly {
        (bool refunded, ) = payable(admin).call{value: amount}("");
        require(refunded, "Fee: Unable to withdraw ETH ");
    }

    function getFees(string memory key) public view returns (uint256) {
        bytes32 _key = _stringToBytes32(key);
        return fees[_key];
    }

    function updateFees(string memory key, uint256 value) external adminOnly {
        bytes32 _key = _stringToBytes32(key);
        fees[_key] = value;
    }

    function _stringToBytes32(string memory source)
        private
        pure
        returns (bytes32 result)
    {
        bytes memory tempEmptyStringTest = bytes(source);
        if (tempEmptyStringTest.length == 0) {
            return 0x0;
        }

        assembly {
            result := mload(add(source, 32))
        }
    }
}
