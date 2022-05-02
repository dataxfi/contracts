pragma solidity 0.8.12;

// Copyright BigchainDB GmbH and Ocean Protocol contributors
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0

interface IFactoryRouter {
    function getOPCFee(address baseToken) external view returns (uint256);

    function getOPCFees() external view returns (uint256, uint256);

    function getOPCConsumeFee() external view returns (uint256);

    function getOPCProviderFee() external view returns (uint256);

    function isFixedRateContract(address) external view returns (bool);
}
