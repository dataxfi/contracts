pragma solidity >=0.8.0 <0.9.0;
import "../interface/IUniV2Router01.sol";
import "../interface/IStorage.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/ownable.sol";
//import "../Base.sol";
contract UniV2Adapter is IStorage {

    IUniswapV2Router02 public uniswapRouter;
    using SafeERC20 for ERC20;
    uint currentVersion;

    constructor(address _routerAddress, uint _currentVersion, uint _StorageAddress)
    {
        uniswapRouter = IUniswapV2Router02(_routerAddress);
        IStorage reg = IStorage(_StorageAddress);
        currentVersion = _currentVersion;
    }
        modifier availableAmt( uint256 amountOut) {
            require(msg.value > amountOut, "balance-insufficient");
        }


    function setVersionInStorage() onlyOwner {
        return reg.upgradeContractAddresses(keccak256("currentVersionAdapter", currentVersion),address(this));
    }



       /** @dev swaps ETH to Exact Ocean
     * oceanAmount
     * path
     * deadline
     */
    function swapETHtoExactTokens(
        uint256 amountOut,
        address[] calldata path,
        uint256 deadline
    ) external availableAmt(amountOut) payable returns (uint256 memory amountsOut) {
       // using the uniswap router contract.
        amountsOut = uniswapRouter.swapETHForExactTokens{value: msg.value}(
            amountOut,
            path,
            msg.sender,
            deadline
        );
        require(
            token.transfer(msg.sender, address(this).balance),
            "Error: ETH Refund Failed"
        );
    }
    /** @dev swaps Exact ETH to Ocean
     * oceanAmount
     * path
     * deadline
     */
    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external availableAmt(amountOutMin) payable returns (uint256 memory amountsOut) {
        // calling external router for the swap
        amountsOut = uniswapRouter.swapExactETHForTokens{value: msg.value}(
            amountOutMin,
            path,
            msg.sender,
            deadline
        );
    
        require(
            token.transfer(msg.sender, address(this).balance), "Error: ETH Refund Failed"
        );
    }
/* swaps exact ERC20 token to ERC20 tokens (for  ocean primarily).
*/
    function swapTokensForExactETH(
        uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline
    ) external availableAmt(amountOut) payable returns (uint256 memory amountsOut)
    {
        // only calling the given function given it implements the ETH transfer within the logiv
        amountsOut = uniswapRouter.swapTokensForExactETH(amountOut, amountInMax, path, msg.sender, deadline);

    }


    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline) 
    external 
    availableAmt(amountIn) payable returns(uint256 memory amountsOut)
    {
        amountsOut = uniswapRouter.swapExactTokensForETH(amountIn,amountOutMin,path, to,deadline);
    }


        function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256 memory amountsOut) {
        amountsOut = uniswapRouter.swapExactTokensForTokens(
            amountIn,
            amountOutMin,
            path,
            msg.sender,
            deadline
        );
    
    require(token.transfer(msg.sender, address(this).balance), "Error: token refund failed/check-txn");
    
    }

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256 memory amountsOut) {
        amountsOut = uniswapRouter.swapTokensForExactTokens(
            amountOut,
            amountInMax,
            path,
            msg.sender,
            deadline
        );
        require(token.transfer(msg.sender, address(this).balance), "Error: token refund failed/check-txn");
    
    }


    
    receive() external payable {

    }
}


