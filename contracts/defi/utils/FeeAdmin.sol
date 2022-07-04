pragma solidity >=0.8.0 <0.9.0;

//Copyright of DataX Protocol contributors
//SPDX-License-Identifier: BSU-1.1

import "./Admin.sol";

contract FeeAdmin is Admin {
    mapping(bytes32 => uint256) public fees;

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
