// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "../interface/IDFY_Hard_1155.sol";

contract DFY_Hard_1155 is
    AccessControl,
    IDFY_Hard_1155,
    ERC1155,
    ERC1155Burnable
{
    using Counters for Counters.Counter;
    using Address for address;

    // Minter role
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    // Contract call create collection
    address public factory;

    // Admin of collection
    address payable public originalCreator;

    // Royalty rate default of collection
    uint256 public defaultRoyaltyRate;

    // CID of collection
    string public collectionCID;

    // Base URI NFT Token
    string public constant collectionBaseUri =
        "https://defiforyou.mypinata.cloud/ipfs/";

    // Total NFT_Hard_721 token
    Counters.Counter private _totalToken;

    // Name NFT_Hard_721 token
    string public name;

    // Name NFT_Hard_721 token
    string public symbol;

    // Mapping token to CID
    // TokenId => CID
    mapping(uint256 => string) public cidOfToken;

    // Mapping token id to royalty rate
    // Token id => royalty rate
    mapping(uint256 => uint256) public royaltyRateOfToken;

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _collectionCID,
        uint256 _defaultRoyaltyRate,
        address _evaluationAddress,
        address payable _owner
    ) ERC1155("") {
        factory = msg.sender;
        originalCreator = _owner;
        collectionCID = _collectionCID;
        defaultRoyaltyRate = _defaultRoyaltyRate;
        _setupRole(DEFAULT_ADMIN_ROLE, _owner);
        _setupRole(MINTER_ROLE, _owner);
        name = _name;
        symbol = _symbol;

        if (
            _evaluationAddress.isContract() && _evaluationAddress != address(0)
        ) {
            _setupRole(MINTER_ROLE, _evaluationAddress);
        }
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155, AccessControl)
        returns (bool)
    {
        return
            interfaceId == type(IDFY_Hard_1155).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function collectionURI() public view returns (string memory) {
        return string(abi.encodePacked(_baseURI(), collectionCID));
    }

    function _baseURI() internal pure returns (string memory) {
        return collectionBaseUri;
    }

    function mint(
        address _assetOwner,
        uint256 _amount,
        string memory _cid,
        bytes memory _data,
        uint256 _royaltyRate
    ) external override onlyRole(MINTER_ROLE) returns (uint256 tokenId) {
        // Generate token id
        tokenId = _totalToken.current();

        // Add mapping cid of token id token id
        cidOfToken[tokenId] = _cid;

        // Set royalty rate to token
        royaltyRateOfToken[tokenId] = _royaltyRate;

        // Mint token
        _mint(_assetOwner, tokenId, _amount, _data);

        // Update total token
        _totalToken.increment();

        return tokenId;
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    function setDefaultRoyaltyRateCollection(uint256 _newRoyaltyRate)
        external
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        uint256 currentRoyaltyRate = defaultRoyaltyRate;

        defaultRoyaltyRate = _newRoyaltyRate;

        emit CollectionRoyaltyRateChanged(currentRoyaltyRate, _newRoyaltyRate);
    }
}
