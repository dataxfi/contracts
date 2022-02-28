pragma solidity >=0.8.0 <0.9.0;

//SPDX-License-Identifier: BSU-1.1
import "@openzeppelin/contracts/utils/access/Ownable.sol";

interface IStorage {

    uint public versionRegistry;
    mapping(bytes32 => address) addressStorage;
    mapping(bytes32 => uint256) parameterStorage;

function getAddressContract(bytes32 _key) public  returns(address);
function getCurrentVersion() public returns(uint) ;
function getStateParams(bytes32 _key) public returns(uint256);
function getStateParams() public returns(uint256);

function upgradeNewVersion(uint  newVersion) public  onlyGov returns(address);
function upgradeContractAddresses(bytes32 key , address newRouter) public onlyGov ;
function upgradeStateParameters(bytes32 key , uint256 newValue)  public onlyGov ;

}