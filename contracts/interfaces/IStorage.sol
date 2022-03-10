pragma solidity >=0.8.0 <0.9.0;

//SPDX-License-Identifier: BSU-1.1

/** @notice : interface to find the current state of addresses of router , adapter protocol functions and other parameters.
 */
interface IStorage {
    /** @dev gets the address of the contract whose hash key is defined
     * @param key  is the keccak256("<<ContractName>>", <<ContractVersion>>) value of key  on which its address will be stored (when the address is created).
     * @return returns the current address of the given contract
     */
    function getContractAddress(bytes32 key) external returns (address);

    /** @dev gets the parameter for the given contract (fees for staking and )
     * @param key value is being defined by  keccak256("<<VariableName>>"). this is minimalist implementation imported by other contracts
     * @return the corresponding parameter value
     */
    function getParam(bytes32 key) external returns (uint256);

    /** @dev storing the new contract address which is deployed.
     * @param key is the value keccak256("<<ContractName>>", <<ContractVersion>>)
     */
    function updateContractAddress(bytes32 key, address newAddress) external;

    /** @dev storing the new parameter (fees) which is upgraded in the present contracts.
     */
    function updateParam(bytes32 key, uint256 newValue) external;
}
