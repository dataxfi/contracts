pragma solidity >=0.8.0 <0.9.0;
// SPDX-License-Identifier: BSU-1.1
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../Base.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title CommunityFeeCollector
 * @dev DataX Protocol Community Fee Collector contract
 *      allows users to pay very small fee in order to support the community of
 *      DataX Protocol and provide a sustainble development.
 */
contract CommunityFeeCollector is Ownable, Base {
    address payable private collector;

    /**
     * @dev constructor
     *      Called prior contract deployment. set the controller address and
     *      the contract owner address
     * @param newCollector the fee collector address.
     * @param owner the contract owner address
     */
    constructor(address payable newCollector, address owner) public Ownable() {
        require(
            newCollector != address(0) && owner != address(0),
            "CommunityFeeCollector: collector address or owner is invalid address"
        );
        collector = newCollector;
        transferOwnership(owner);
    }

    /**
     * @dev fallback function
     */
    fallback() external payable {}

    /**
     * @dev receive ETH
     */
    receive() external payable {}

    /**
     * @dev withdrawETH
     *      transfers all the accumlated ether the collector address
     */
    function withdrawETH() external payable {
        collector.transfer(address(this).balance);
    }

    /**
     * @dev withdrawToken
     *      transfers all the accumlated tokens the collector address
     * @param tokenAddress the token contract address
     */
    function withdrawToken(address tokenAddress) external {
        require(
            tokenAddress != address(0),
            "CommunityFeeCollector: invalid token contract address"
        );

        require(
            IERC20(tokenAddress).transfer(
                collector,
                IERC20(tokenAddress).balanceOf(address(this))
            ),
            "CommunityFeeCollector: failed to withdraw tokens"
        );
    }

    /**
     * @dev changeCollector
     *      change the current collector address. Only owner can do that.
     * @param newCollector the new collector address
     */
    function changeCollector(address payable newCollector) external onlyOwner {
        require(
            newCollector != address(0),
            "CommunityFeeCollector: invalid collector address"
        );
        collector = newCollector;
    }
}
