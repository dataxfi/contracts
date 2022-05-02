pragma solidity >=0.8.0 <0.9.0;
// SPDX-License-Identifier: BSU-1.1

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/SafeMath.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IStorage.sol";

contract Fees {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    uint256 private constant BASE = 1e10;
    uint256 private constant PRCNT = 100;
    IStorage private store;

    constructor(address _storage) {
        store = IStorage(_storage);
    }

    function calcDataXFees(uint256 baseTokenAmount, string calldata feeType)
        public
        view
        returns (uint256)
    {
        uint256 fees = store.getFees(feeType);
        return baseTokenAmount.mul(fees).div(BASE).div(PRCNT);
    }

    function calcRefFees(uint256 baseTokenAmount, uint256 refFees)
        public
        pure
        returns (uint256)
    {
        return baseTokenAmount.mul(refFees).div(BASE).div(PRCNT);
    }
}
