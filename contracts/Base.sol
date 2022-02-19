pragma solidity >=0.8.0 <0.9.0;

//SPDX-License-Identifier: BSU-1.1

contract Base {
    bool internal _mutex;

    // mutex safety lock to avoid Reentry attack
    modifier _lock_() {
        require(!_mutex, "ERR_REENTRY");
        _mutex = true;
        _;
        _mutex = false;
    }

    // check if invocation is not a reentry call
    modifier _viewlock_() {
        require(!_mutex, "ERR_REENTRY");
        _;
    }
}
