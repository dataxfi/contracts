pragma solidity >=0.8.0 <0.9.0;

//Copyright of DataX Protocol contributors
//SPDX-License-Identifier: BSU-1.1

contract Const {
    uint256 public constant BONE = 1e18;
    uint256 public constant MIN_BPOW_BASE = 1 wei;
    uint256 public constant MAX_BPOW_BASE = (2 * BONE) - 1 wei;
    uint256 public constant BPOW_PRECISION = BONE / 1e10;
    uint256 public constant MAX_INT = 2**256 - 1;
    uint256 public constant ZERO_FEES = 0;
}
