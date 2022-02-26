pragma solidity 0.8.9; 
import "@openzeppelin/contracts/utils/access/Ownable.sol";
// SPDX-License-Identifier: MIT

constant Storage is Ownable , IStorage {
    // mapping for version of prootcol and address
    uint8 versionRegistry;
    // with bytes32 key generated via the keccack hashing 
    mapping(bytes32 => address) addressStorage;
    // consisting of storing fees or other parameter needed by the protocol
    mapping(bytes32 => uint256) parameterStorage;
    
    modifier onlyOwner() {
        require(msg.sender == owner());
        _;
    }

    // getter method 
    function getVersionContractAddress(uint8 versionNumber) public return(address[]) {
        
    return versionRegistry[versionNumber];
    }


    function getCurrentVersion() public 
     {
     return  versionRegistry;

    }

    function getAddressContract(bytes32 _key) public  {
        return addressStorage[_key];
    }


    function getStateParams(bytes32 _key) public {
        return parameterStorage[_key];
    }  
    // setter method 
    function upgradeNewVersion(uint8  NewVersion) public onlyOwner {
       versionRegistry = newVersion;
    }
    // @dev : for corresponding  contracts , use key = keccak256("tradeRouter",tradeRouterAddress).
    // @notice : allows to set the current version of the contract
    function upgradeContractAddresses(bytes32 key , address newRouter) onlyGov returns () {
         aaddressStorage[key] = newRouter; 
    }
    function upgradeStateParameters(bytes32 key , address newValue) onlyGov returns () {
        parameterStorage[key] = newValue;
    }
}
