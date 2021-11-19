// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../interface/IDFY_Hard_721.sol";

contract DFY_Hard_721 is 
    IDFY_Hard_721,
    Initializable,
    UUPSUpgradeable,
    ERC721Upgradeable,
    PausableUpgradeable
{
    using CountersUpgradeable for CountersUpgradeable.Counter;
    using AddressUpgradeable for address;

    // Total NFT_Hard_721 token
    CountersUpgradeable.counter public totalToken;

    // Name NFT_Hard_721 token
    string public name;

    // Name NFT_Hard_721 token
    string public symbol;
    
    // Base URI NFT Token
    string public tokenBaseUri;

    // Mapping token to CID
    // TokenId => CID
    mapping(uint256 => string) public cidOfToken;

    // Mapping evaluator to NFT
    // Address evaluator  => listTokenId;
    mapping(address => uint256[]) public tokenOfEvaluator;

    function initialize(
        string memory _name,
        string memory _symbol,
        string memory _uri
    ) public initializer {
        __ERC721_init(_name,_symbol);
        __Pausable_init();
        __UUPSUpgradeable_init();

        name = _name;
        symbol = _symbol;
        
        _setBaseURI(_uri);
    }

    function signature() 
        external
        view
        override
        returns(bytes4) 
    {
        return type(IDFY_Hard_721).interfaceId;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) 
        internal 
        override 
        whenNotPaused 
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _authorizeUpgrade(address) 
        internal
        override{}

    function _setBaseURI(string memory _newURI) internal {
        require(bytes(_newURI).length > 0, "Blank");
        tokenBaseUri = _newURI;
    }

    function setBaseURI(
        string memory _newURI
    ) 
        external
        override
        whenNotPaused
    {
        _setBaseURI(_newURI);
    }

    function pause()
        external 
        override
    {
        _pause();
    }

    function unpause() 
        external
        override 
    {
        _unpause();
    }

    function _exists(uint256 _tokenId) internal view virtual returns (bool) {
        return bytes(cidOfToken[_tokenId]).length > 0;
    }

    function uri(uint256 _tokenId) 
        public
        view
        virtual
        override
        whenNotPaused
        returns (string memory)
    {
        require(_exists(tokenId), "Invalid token");

        return bytes(tokenBaseUri).length > 0 ? string(abi.encodePacked(tokenBaseUri, cidOfToken[tokenId])) : "";
    }

    function mint(
        address _evaluator,
        address _owner,
        string memory _cid
    )
        external
        override
        whenNotPaused
        returns (uint256 tokenId)
    {
        // Generate token id
        tokenId = totalToken.current();

        // Add mapping cid of token id token id
        cidOfToken[tokenId] =_cid;

        // Add token id to mapping token of cid of token id
        tokenOfEvaluator[_evaluator] = tokenId;

        // Mint token
        _mint(_owner, tokenId);

        // Update total token
        totalToken.increment();

        return tokenId;
    }

    function updateCID(
        uint256 _tokenId,
        string memory _newCID
    ) 
        external
        override 
        whenNotPaused
    {
        // Check for empty CID string input
        require(bytes(_newCID).length > 0, "Empty CID");

        // Check if token exists
        require(bytes(cidOfToken[_tokenId]).length > 0, "InvalidToken");

        // Update CID
        cidOfToken[_tokenId] = _newCID;
    }

}