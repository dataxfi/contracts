// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract DataXOGNFT is ERC721, Ownable {
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdTracker;

    uint256 public constant MAX_ELEMENTS = 500;
    uint256 public constant MAX_BY_MINT = 1;
    uint256 public constant START_AT = 1;

    address public adminAddress;
    string public baseTokenURI;

    event NewMint(uint256 indexed id, address indexed to);

    constructor(string memory baseURI) ERC721("DataX OG", "DATAXOG") {
        setBaseURI(baseURI);
    }

    /**
     * @dev totalSupply
     * internally returns total supply of OG tokens
     */
    function _totalSupply() internal view returns (uint256) {
        return _tokenIdTracker.current();
    }

    /**
     * @dev totalMint()
     * returns total supply of OG tokens
     */
    function totalMint() public view returns (uint256) {
        return _totalSupply();
    }

    /**
     * @dev mint
     * mints a new OG NFT to a given address.
     * Only owner can mint.
     */
    function mint(address _to) public onlyOwner {
        uint256 total = _totalSupply();
        require(total <= MAX_ELEMENTS, "Error: Max limit");
        _mintAnElement(_to);
    }

    /**
     * @dev _mintAnElement
     * internally called to mint
     */
    function _mintAnElement(address _to) private {
        uint256 id = _totalSupply() + START_AT;
        _tokenIdTracker.increment();
        _safeMint(_to, id);
        emit NewMint(id, _to);
    }

    /**
     * @dev _baseURI
     * internally called to return current baseUri
     */
    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    /**
     * @dev setBaseURI
     * callable by owner to set new BaseURI
     */
    function setBaseURI(string memory baseURI) public onlyOwner {
        baseTokenURI = baseURI;
    }

    /**
     * @dev withdrawETH
     * transfers all the accumlated ether the collector address
     */
    function withdrawETH() external payable onlyOwner {
        address _owner = owner();
        payable(_owner).transfer(address(this).balance);
    }

    /**
     * @dev withdrawToken
     *      transfers all the accumlated tokens the collector address
     * @param tokenAddress the token contract address
     */
    function withdrawToken(address tokenAddress) external onlyOwner {
        require(
            tokenAddress != address(0),
            "Error: Invalid token contract address"
        );
        address _owner = owner();
        require(
            IERC20(tokenAddress).transfer(
                _owner,
                IERC20(tokenAddress).balanceOf(address(this))
            ),
            "Error: Failed to withdraw tokens"
        );
    }

    receive() external payable {}
}
