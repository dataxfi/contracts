pragma solidity >=0.8.0 <0.9.0;

//SPDX-License-Identifier: BSU-1.1

interface IStorage {
    function getAddressContract(bytes32 _key) external returns (address);

    function getCurrentVersion() external returns (uint256);

    function getStateParams(bytes32 _key) external returns (uint256);

    function upgradeNewVersion(uint256 newVersion) external returns (address);

    function upgradeContractAddresses(bytes32 key, address newRouter) external;

    function upgradeStateParameters(bytes32 key, uint256 newValue) external;
}
