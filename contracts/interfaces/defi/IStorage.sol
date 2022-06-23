pragma solidity >=0.8.0 <0.9.0;

//SPDX-License-Identifier: BSU-1.1

interface IStorage {
    function getContractAdd(string calldata name, uint8 version)
        external
        view
        returns (address);

    function getCurrentVersion(string calldata name)
        external
        view
        returns (uint8);

    function updateContractVersion(
        string calldata name,
        uint8 version,
        address value
    ) external;

    function getFees(string calldata key) external view returns (uint256);

    function updateFees(string calldata key, uint256 value) external;
}
