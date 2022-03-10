pragma solidity >=0.8.0 <0.9.0;

//SPDX-License-Identifier: BSU-1.1


/** @notice : interface to find the current state of addresses of router , adapter protocol functions and other parameters.
 */
interface IStorage {
    /// @notice gets the address of the contract whose hash key is defined    
    /// @param _key  is the keccak256("<<ContractName>>",contractAddress) value of key  on which its address will be stored (when the address is created).
    /// @return returns the address of the corr
    function getAddressContract(bytes32 _key) external returns (address);


    // @def gets the current version of contract
    function getCurrentVersion() external returns (uint256);

    // @dev gets the parameter for the given contract (fees for staking and )
    //@param key value is being defined by  keccak256("<<VariableName>>", variableValue). this is minimalist implementation imported by other contracts 
    // @returns the corresponding parameter value .
    function getStateParams(bytes32 _key) external returns (uint256);

    // @dev storing the new contract address which is deployed.
    // @param key is the value keccak256("contractName", contractAddress).
    function upgradeContractAddresses(bytes32 key, address newRouter) external;

    // @dev storing the new parameter (fees) which is upgraded in the present contracts.
    function upgradeStateParameters(bytes32 key, uint256 newValue) external;

}
