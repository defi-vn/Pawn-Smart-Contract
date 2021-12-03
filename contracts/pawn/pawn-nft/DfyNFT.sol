/* SPDX-License-Identifier: UNLICENSED */

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract DfyNFT is ERC721Enumerable, ERC721URIStorage, Ownable {
    string private baseURI;
    mapping(address => bool) private _operators;
    mapping(uint256 => uint256) private _properties;

    event MintNFT(
        address recipient,
        uint256 tokenId,
        uint256 properties,
        uint256 fullData
    );
    event SetProperties(uint256 tokenId, uint256 properties);
    event SetBaseURI(string uri);

    constructor() ERC721("DEFI NFT", "DEFI NFT 721") {}

    modifier onlyOperator() {
        require(_operators[_msgSender()]);
        _;
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function setBaseURI(string memory uri) public onlyOwner {
        baseURI = uri;
        emit SetBaseURI(uri);
    }

    function setOperator(address operator, bool isOperator) external onlyOwner {
        _operators[operator] = isOperator;
    }

    function mintNFT(
        address recipient,
        uint256 tokenId, // blocks 8-12
        uint256 properties // blocks 1-7
    ) public onlyOperator returns (uint256) {
        _safeMint(recipient, tokenId);
        _setTokenURI(tokenId, string(abi.encodePacked(tokenId)));
        _properties[tokenId] = properties;
        uint256 fullData = (tokenId << 140) + properties;
        emit MintNFT(recipient, tokenId, properties, fullData);
        return tokenId;
    }

    function setProperties(uint256 tokenId, uint256 properties)
        public
        onlyOperator
    {
        _properties[tokenId] = properties;
        emit SetProperties(tokenId, properties);
    }

    function getOwnedTokenIds(address userAddr)
        public
        view
        returns (uint256[] memory)
    {
        uint256 numNFTs = balanceOf(userAddr);
        if (numNFTs == 0) return new uint256[](0);
        else {
            uint256[] memory ownedtokenIds = new uint256[](numNFTs);
            for (uint256 i = 0; i < numNFTs; i++)
                ownedtokenIds[i] = tokenOfOwnerByIndex(userAddr, i);
            return ownedtokenIds;
        }
    }

    function getProperties(uint256 tokenId) public view returns (uint256) {
        return _properties[tokenId];
    }

    function getNFTData(uint256 tokenId) public view returns (uint256) {
        return ((tokenId << 140) + _properties[tokenId]);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) {
        ERC721Enumerable._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId)
        internal
        override(ERC721, ERC721URIStorage)
    {
        ERC721URIStorage._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return ERC721URIStorage.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return ERC721Enumerable.supportsInterface(interfaceId);
    }
}
