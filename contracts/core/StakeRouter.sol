pragma solidity >=0.8.0 <0.9.0;
//SPDX-License-Identifier: BSU-1.1
import "../Base.sol";
import "../interfaces/IPool.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol"; 
import "../interfaces/ICommunityFeeCollector.sol";
import "../interfaces/IUniV2Adapter.sol";
import "../interfaces/IStakeRouter.sol";
import "../interfaces/IStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol"
// contract by ocean for finding the details about the data tokens being staked in the pools.
import "../interfaces/IBfactory.sol";
contract StakeRouter is   IStakeRouter , Base {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    ITradeRouter adapter;
    ICommunityFeeCollector collector;
    IStorage reg ;
    IBFactory balancerFac;
    IPool BPool;
    // current version of stakerouter (also stored  in the storage, but still used for  direct lookup).
    uint public currentVersionSR;
 constructor(address adapterAddress, address Bfactory, address BPool ,  uint _version , uint _fees ,address  _StorageAddress, address _collectorAddress , address _tokenOcean ) {
        adapter = ITradeRouter(adapterAddress);
        reg = IStorage(_StorageAddress);
        collector = ICommunityFeeCollector(_collectorAddress);
        balancerFac = IBFactory(Bfactory);
        BPool = IPool(BPool);
        // set collector fees
        reg.setParam(keccak256("CollectorFeesSR",_collectorAddress), _fees );
        reg.setParam(keccak256("VersionSR",_collectorAddress), _version );
        setCollector(_collectorAddress);
        currentVersionSR = _version;
        // set also the stakeRouter address in the storage
        reg.updateContractAddress(keccak256("StakeRouter", _version), address(this));
        
        }
// only owner(or the multisig from the gov) will be operating on the following functions.
    modifier onlyGov {
        require(msg.sender == Owner());
    _;
    }
    
    function getCurrentVersion()  public returns(uint) {
        return(currentVersionSR);
    }
    function setCollector(address newAddress) public onlyGov {
        collector.changeCollector(newAddress);
    }

    function setParamUint(uint256 value, string parameterName ) public onlyGov {
       bytes32 key = keccak256("parameterName", currentVersionSR);
       reg.updateParam(key, value);
    }
    
    // @dev : address receiving the fees from the swapping operation
    function setCollector(address payable _feeCollector) onlyGov public {
        require(collector.changeCollector(_feeCollector), "permission denied");
    }
   /** takes  the  token amount from any supported ERC20 <> DT lp pair and stakes it to the base pair.
@param tokenAmountsOut is the amount of exact dataToken that you want to be staked in the balancer pool (excl the fees).
@param amountIn defines the ERC20 tokens that you want to swap.
@param path is the array of the address array for swap from the given user input token <> underlying DT <> baseToken.
@param deadline is the  max timeline in which the order must be filled 
@param refStakingAddress consist of  the address of the collector contract of the third party service provider.
@param refStakingFee is the fee value that we extract from the provider 
 */    
function StakeERC20toDT(address dtpoolAddress,address amountIn,  uint256[] calldata tokenAmountsOut,address[] calldata path,address datatoken,  uint256 deadline, address refStakingAddress, uint256 refStakingFees) external _lock_ payable returns(uint256 memory DToken_results)
     {
        // Step 1 : swapping the exact tokens to the given ocean supported DTpool.
            adapter.swapExactTokenstoDataToken(
            amountIn,
            tokenAmountsOut[tokenAmountsOut - 1],
            path,
            address(this),
            deadline
        );
        // corresponding ocean DTaddress. 
        address dtaddress = datatoken;
        // an optional verification in case whether the token is available datatoken for the bpools .
        require(balancerFac.isOceanToken(dtaddress), "StakeRouter::WrongAddress() wrong token supplied, check whitelisted tokens again");
    
        // now  staking the amount from the SR to pool
        // finding balance of token currently in SR
        uint256 balanceOfToken = IERC20(dtaddress).BalanceOf(address(this)) - getCommunityFees();
        
        /** now for calling the function for adding single side liquidity , first we need the parameters
        tokenAmountIn (which is  balanceOfToken) , 
        for minPoolAmountOut , 
            - we will approximately find via getAmountOutExactIn() function , 
                - with parameters tokenIn(path[path.length-2]) (as the last swap will be between  the intermediate token at path[length-2] and DT(ie at  length-1))
                - tokenOut(path[dtaddress -  1])
                - amountIn :- balanceOfToken;
                - consumeMarketSwapFee :- for now from BPool.getSwapFees();
         */

         uint256 minPoolAmountOut = BPool.getAmountInExactOut(path[path.length - 2],dtaddress, balanceOfToken, BPool.getSwapFees())[0];
        require(BPool.joinswapExternAmountIn(
            balanceOfToken,
            minPoolAmountOut
        ), "staking failed");
       // also the stake fees for the referal user will be transferred if the staking is successful.
       // here we will assume that the refstakingAddress has approved the StakeRouter for the transfer of the fees.
        IERC20.safeTransferFrom(dtaddress,refStakingAddress, address(this), refStakingFees);

        // and then approving the collector to transfer the amount 
        uint256 totalAmount =  IERC20(dtaddress).balanceOf(address(this))
        IERC20.safeApprove(dtaddress, _collectorAddress, totalAmount);
        collector.withdrawTokens(dtaddress);

    }

    /** stake ETH into the dataTokens , the workflow will be same as previously but will just use ETH specific swap functions 
    
     */
function StakeETHtoDT(address dtpoolAddress, uint256 amountDTOut, address[] calldata path, address datatoken, uint256 deadline, address refStakingAddress, uint256 refStakingFees) public payable _lock_ {
    adapter.swapETHForExactTokens(amountDTOut, path, deadline, address(this));

    require(balancerFac.isOceanToken(datatoken), "StakeRouter::WrongAddress() wrong token supplied, check whitelisted tokens again");
    
    uint256 balanceOfToken = IERC20(dtaddress).BalanceOf(address(this)) - getCommunityFees();

    uint256 minPoolAmountOut = BPool.getAmountInExactOut(path[path.length - 2],datatoken, balanceOfToken, BPool.getSwapFees())[0];
    
    require(BPool.joinswapExternAmountIn(
        balanceOfToken,
        minPoolAmountOut
    ), "staking failed");

    IERC20.safeTransferFrom(datatoken,refStakingAddress, address(this), refStakingFees);

    uint256 totalAmount =  IERC20(dtaddress).balanceOf(address(this))
        IERC20.safeApprove(dtaddress, _collectorAddress, totalAmount);
        collector.withdrawTokens(dtaddress);
}

function StakeDTtoDT(address dtpoolAddress, uint256 amountDTOut, uint256 amountDTMaxIn, address dataToken,  address[] calldata  path , uint dataToken,  address refStakingAddress , uint256 refStakingFees) payable  external
{   // uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline
    adapter.swapExactDataTokenforDataToken(amountDTMaxIn, amountDTOut, path, address(this),dataToken);

    require(balancerFac.isOceanToken(datatoken), "StakeRouter::WrongAddress() wrong token supplied, check whitelisted tokens again");

    //and the remaining portion remains the same logic 

    require(balancerFac.isOceanToken(datatoken), "StakeRouter::WrongAddress() wrong token supplied, check whitelisted tokens again");
    
    uint256 balanceOfToken = IERC20(dtaddress).BalanceOf(address(this)) - getCommunityFees();

    uint256 minPoolAmountOut = BPool.getAmountInExactOut(path[path.length - 2],datatoken, balanceOfToken, BPool.getSwapFees())[0];
    require(BPool.joinswapExternAmountIn(
        balanceOfToken,
        minPoolAmountOut
    ), "staking failed");

    IERC20.safeTransferFrom(datatoken,refStakingAddress, address(this), refStakingFees);

    uint256 totalAmount =  IERC20(dtaddress).balanceOf(address(this))
        IERC20.safeApprove(dtaddress, _collectorAddress, totalAmount);
        collector.withdrawTokens(dtaddress);

}


    function UnstakeDTtoERC20(address dtpoolAddress, uint256 poolAmountIn ,address[] calldata  path ,uint256 deadline, address refUnstakingAddress , uint256 refUnstakingFees ) external {
        // first removing single side pair liquidity to retrive the ocean
    uint256 minAmountOut = BPool.getAmountOutExactIn(path[path.length - 1],datatoken,poolAmountIn,BPool);
    uint256 ExactDTAmountOut =  BPool.exitswapPoolAmountIn(poolAmountIn, minAmountOut);
        // fees transfer to the collector 
    uint256 feesCollector =  getCommunityFees();


    // converting exact DT to the given tokens and sends to StakeRouter.
        adapter.swapExactDatatokensforTokens(
        ExactDTAmountOut,
        amountOutMin,
        path,
        address(this),
        deadline
        );

    uint256 finalAmountOut =  SafeMath.sub(IERC20.balanceOf(address(this)) - getCommunityFees());
    // unstaking fees  retrieval
    IERC20.safeTransferFrom(datatoken, address(this),to, finalAmountOut );
    // also fetching the refStaking fees by the third party provider .
    IERC20.safeTransferFrom(datatoken,refstakingAddress, address(this), refStakingFees);

    collector.withdrawToken(datatoken);
    
    
    
    }


function UnstakeDTtoETH(address dtpoolAddress, uint256 poolAmountIn, uint256 amountOutMin , address[] calldata  path , address refUnstakingAddress , uint256 refUnstakingFees )  public payable  {

     // first removing single side pair liquidity to retrive the ocean
    uint256 minAmountOut = BPool.getAmountOutExactIn(path[path.length - 1],datatoken,poolAmountIn,BPool);
    uint256 ExactDTAmountOut =  BPool.exitswapPoolAmountIn(poolAmountIn, minAmountOut);
        // fees transfer to the collector 
    uint256 feesCollector =  getCommunityFees();


    // converting exact DT to the given tokens and sends to StakeRouter.
        adapter.swapExactDatatokensforETH(
        ExactDTAmountOut,
        amountOutMin,
        path,
        address(this),
        deadline
        );

    uint256 finalAmountOut =  SafeMath.sub(IERC20.balanceOf(address(this)) - getCommunityFees());
    // transfer to the  relevant  address doing the unstaking.
    IERC20.safeTransferFrom(datatoken, address(this),to, finalAmountOut );
    // also fetching the refStaking fees by the third party provider .
    IERC20.safeTransferFrom(datatoken,refstakingAddress, address(this), refStakingFees);

    collector.withdrawToken(datatoken);
    

}





function UnstakeDTtoDT(address dtpoolAddress, uint256 poolAmountIn, uint256 amountOutMin, address[] calldata  path ,address to,  address refUnstakingAddress , uint256 refUnstakingFees ) payable public {
// similar to the previous one , just the swaps will be from the base DT to arbitrary DT needed by user.
uint256 minAmountOut = BPool.getAmountOutExactIn(path[path.length - 1],datatoken,poolAmountIn,BPool);
uint256 ExactDTAmountOut =  BPool.exitswapPoolAmountIn(poolAmountIn, minAmountOut);

adapter.swapExactDatatokensforDatatokens(
        ExactDTAmountOut,
        amountOutMin,
        path,
        address(this),
        datatoken,
        deadline,
        refUnstakingAddress,
        refUnstakingFees
        );

// now sending the total data tokens (total - communityfees) back to the staker address

uint DtAmountTransferred = IERC20(datatoken).balanceOf(address(this)) - getCommunityFees();

IERC20(datatoken).safeTransferFrom(datatoken,address(this), to, DtAmountTransferred );

// and the remaining value is transferred to the collector via approval.

IERC20(datatoken).safeApprove(_collectorAddress, DtAmountTransferred);

collector.withdrawToken(datatoken);
}





/**
providing revert txn possiblity in case of txn revert .
 */
 fallback() external payable {}

    /**
     * @dev receive ETH
     */
    receive() external payable {}


}
