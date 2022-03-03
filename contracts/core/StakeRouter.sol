pragma solidity >=0.8.0 <0.9.0;
//SPDX-License-Identifier: BSU-1.1
import "../Base.sol";
import "../interfaces/IPool.sol";

contract StakeRouter is Base , ICommunityFeeCollector,IUniswapV2Adapter , IStorage{
    using SafeMath for uint256;
    IUniV2Adapter adapter;
    ICommunityFeeCollector collector;
    address public dtpoolAddress
    // parameter constant for fees and 
    uint256 public communityFee;
   
    uint public currentVersionSR;
      
    constructor(address adapterAddress , address _dtpoolAddress , uint _version , uint _fees ,address  _StorageAddress, address _collectorAddress , address _tokenOcean ) {
       dtpoolAddress = _dtpoolAddress;
        adapter = IUniV2Adapter(adapterAddress);
        IBPool dtpool = IBPool(dtPoolAddress);
        IStorage reg = IStorage(_StorageAddress);
        collector = ICommunityFeeCollector(_collectorAddress);
        currentVersion = _version;
        setCommunityFees(_fees);
        tokenOceanAddress = _tokenOcean;
        }
    modifier onlyGov {
        require(msg.sender == Owner());
    }
    
    
// getter function returning the community fees for the current state of the contracts.
    function getCommunityFees() public returns (uint256) {
        return(communityFees);
    }

    function getCurrentVersion() public returns (uint) {
        return(currentVersionTR);
    }

    function setAddress() public onlyGov {
return reg.upgradeContractAddresses(keccak256("versionTR", currentVersionTR),address(this));
        
    }

    // @dev : sets the counter
    function setCommunityFees(uint _fees ) public onlyGov {
        communityFee = _fees;
    }
    // @dev : address receiving the fees from the swapping operation
    function setCollector(address payable _feeCollector) onlyGov public {
        require(collector.changeCollector(_feeCollector), "permission denied");
    }
  
    //@dev wrapper contract for storing the current version of TR with the corresponding address 
    function setVersionInStorage() public onlyOwner {
        return reg.upgradeContractAddresses(keccak256("versionSR", currentVersionSR),address(this));
    }

    /**  @dev : swaps the value of ETH to exact data token with the path ETH  --> exact tokens --> exact DT
     and only swaps on the single side liquidity 
     @Param amountsOut = amount of data token needed .
    @param  path is addr["ERC20TokenAddress","OceanAddr","DTAddress"]. 
    @ dataToken is the address of the dt which is also called baseToken for the pool contract
    */
    function StakeERC20inDP(
        uint256  tokenamountsOut,
        address[] calldata path,
        address datatoken,
        uint256 deadline,
        uint256[] amountsOut,
    ) external __lock__ payable returns(uint256 memory DToken_results)
     {



        // converting the given ERC20 into the dataToken for staking 
        adapter.swapExactTokenstoDataToken(
            dtpooladdress,
            amountsOut,
            path,
            100
        );
        address dtaddress = path[path.length - 1];
        // now then sending the out amounts (DT's base tokens) from the given contract to the address
        uint256 balanceOfToken = IERC20(pathAddress).BalanceOf(dtaddress);
        adapter.joinswapExternAmountIn(
            balanceOfToken,
            10000000000
        );
        // finally   sending some ERC20  tokens as collector  fees after the operation. 
        collector.withdrawTokens(path[2]);

    }
    //TODO : Stake DT in DataPools
    /**
    path 
    
     */
    function StakeDTInDatapools(
       address[] path
       uint256 tokenAmountIn,
       uint
    ) external  __lock__ payable{
        //  durectly calling the function for adding single side liquidity from the base token .
    dtpool.joinswapExternAmountIn()

    }
    function UnstakeERC20inDP(
        uint256 ExactDataTokenIn,
        uint256 minAmountOut,
        address[] calldata path,
        address datatoken,
        uint256 deadline
    ) external {
        // first removing single side pair liquidity to retrive the ocean
      uint256 ExactOceanAmountOut =  dtpool.exitswapPoolAmountIn(ExactDataTokenIn, dtpool.getAmountOutExactIn(path[path.length - 1],datatoken,ExactDataTokenIn,0));
      
        // fees transfer
        uint256 feesCollector =  getCommunityFees();
        uint256 ExactOceanSwapped =  sub(ExactOceanAmountOut, feesCollector);
        IERC20(oceanToken).safeTransferFrom(oceanToken, feeCollector,  feesCollector); 

      // now converting the ocean to the ETH ad doing the transfer
        adapter.swapExactTokensForTokens(
        ExactOceanAmountOut,
        path,
        datatoken,
       0
        );

    // TODO: unstaking fees is required to be seperate rate to be deducted. 

    }

    //TODO :double liquidity exit . 
    function UnstakeERC20DTandDP(
       uint256 ExactDataTokenIn,
        uint256 minAmountOut,
        address[] calldata path,
        address datatoken,
        uint256 deadline
    ) external {

    }



}
