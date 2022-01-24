// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "../hub/HubInterface.sol";
import "../libs/CommonLib.sol";
import "./IDFY721.sol";

abstract contract DFY721Base is
    ERC721,
    ERC721Enumerable,
    ERC721URIStorage,
    ERC721Burnable,
    AccessControl,
    IDFY721
{
    using SafeERC20 for IERC20;
    using Counters for Counters.Counter;
    using Address for address;

    string public constant CollectionBaseURI =
        "https://defiforyou.mypinata.cloud/ipfs/";

    Counters.Counter private _tokenIdCounter;

    uint256 public defaultRoyaltyRate;
    string public collectionCID;
    address payable private _originalCreator;
    mapping(uint256 => uint256) private _royaltyRateByToken;

    address private _contractHub;

    /** ============================================================ */

    constructor(
        string memory _name,
        string memory _symbol,
        address payable _owner,
        uint256 _royaltyRate,
        string memory _collectionCID,
        address _hub
    ) ERC721(_name, _symbol) {
        _setupRole(DEFAULT_ADMIN_ROLE, _owner);

        _originalCreator = _owner;
        defaultRoyaltyRate = _royaltyRate;
        collectionCID = _collectionCID;

        _contractHub = _hub;

        // TODO: Get NFT Sales & Auction addresses from Hub & set approval for all NFTs owned by the owner
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(IERC165, ERC721, ERC721Enumerable, AccessControl)
        returns (bool)
    {
        return
            interfaceId == type(IDFY721).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev Mint an NFT token and transfer to a user address
     * @param owner is the owner of the token being minted
     * @param royaltyRate is the percentage of the NFT's value that will be paid to the collection creator when it is sold
     * @param tokenCID is the CID string acquired when uploading collection's metadata file to IPFS
     */
    function safeMint(
        address owner,
        uint256 royaltyRate,
        string memory tokenCID
    ) public virtual override {
        uint256 tokenID = _tokenIdCounter.current();

        // Get fee wallet & fee token address from Hub
        (address feeWallet, address feeToken) = HubInterface(_contractHub)
            .getSystemConfig();

        // Get minting fee from Hub
        (, uint256 mintingFee) = HubInterface(_contractHub)
            .getNFTCollectionConfig();

        // Check allowance, balance and transfer minting fee to fee wallet
        CommonLib.safeTransfer(feeToken, msg.sender, feeWallet, mintingFee);

        // Mint NFT token to owner
        _safeMint(owner, tokenID);

        _setTokenURI(tokenID, tokenCID);

        _royaltyRateByToken[tokenID] = royaltyRate;

        _tokenIdCounter.increment();

        emit NFTCreated(owner, tokenID, royaltyRate, tokenCID);
    }

    /**
     * @dev get all tokens held by a user address
     * @param _owner is the token holder
     */
    function tokensOfOwner(address _owner)
        external
        view
        override
        returns (uint256[] memory)
    {
        // get the number of token being hold by _owner
        uint256 tokenCount = balanceOf(_owner);

        if (tokenCount == 0) {
            // If _owner has no balance return an empty array
            return new uint256[](0);
        } else {
            // Query _owner's tokens by index and add them to the token array
            uint256[] memory tokenList = new uint256[](tokenCount);
            for (uint256 i = 0; i < tokenCount; i++) {
                tokenList[i] = tokenOfOwnerByIndex(_owner, i);
            }

            return tokenList;
        }
    }

    /**
     * @dev set the default royalty rate of the collection
     * @param newRoyaltyRate is the value being set as collection's default royalty rate
     */
    function setCollectionDefaultRoyaltyRate(uint256 newRoyaltyRate)
        external
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        uint256 currentRoyaltyRate = defaultRoyaltyRate;

        defaultRoyaltyRate = newRoyaltyRate;

        emit CollectionRoyaltyRateChanged(currentRoyaltyRate, newRoyaltyRate);
    }

    function originalCreator() external view override returns (address) {
        return _originalCreator;
    }

    function royaltyRateByToken(uint256 tokenId)
        external
        view
        override
        returns (uint256)
    {
        return _royaltyRateByToken[tokenId];
    }

    function contractURI() public view returns (string memory) {
        return string(abi.encodePacked(_baseURI(), collectionCID));
    }

    function _baseURI() internal pure override returns (string memory) {
        return CollectionBaseURI;
    }

    /** The following functions are overrides required by Solidity. */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId)
        internal
        override(ERC721, ERC721URIStorage)
    {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function updateCollectionCID(
        string memory newCID
    ) 
        public 
        virtual 
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if(bytes(newCID).length > 0) {
            collectionCID = newCID;
        }
    }
}
