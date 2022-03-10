pragma solidity 0.8.10; 
// SPDX-License-Identifier: MIT

contract Storage  {
    // mapping for version of prootcol and address
     uint public versionRegistry;
    // with bytes32 key generated via the keccack hashing 
    mapping(bytes32 => address) addressStorage;
    // consisting of storing fees or other parameter needed by the protocol
    mapping(bytes32 => uint256) parameterStorage;
    
    address currentOwner;
   
    constructor(uint _currentVersion) {
     currentOwner = msg.sender;
   //  upgradeNewVersion(_currentVersion);
    }

    modifier onlyGov() {
        require(msg.sender == currentOwner);
        _;
    }

    // getter method 
    
    function getAddressContract(bytes32 _key) public  returns(address) {
        return addressStorage[_key];
    }


    function getCurrentVersion() public returns(uint) {
        return  versionRegistry;
    }


    function getStateParams(bytes32 _key) public returns(uint256) {
        return parameterStorage[_key];
    }  
    // setter method 
    function upgradeNewVersion(uint  newVersion) public  onlyGov returns(address)  {
       versionRegistry = newVersion;
    }
    // @dev : for corresponding  contracts , use key = keccak256("tradeRouter",tradeRouterAddress).
    // @notice : allows to set the current version of the contract
    function upgradeContractAddresses(bytes32 key , address newRouter) public onlyGov  {
         addressStorage[key] = newRouter; 
    }
    function upgradeStateParameters(bytes32 key , uint256 newValue)  public onlyGov  {
        parameterStorage[key] = newValue;
    }
}
