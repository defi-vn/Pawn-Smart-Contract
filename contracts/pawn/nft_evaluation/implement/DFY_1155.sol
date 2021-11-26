// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "../interface/IDFY_1155.sol";

contract DFY_1155 is
    Initializable,
    UUPSUpgradeable,
    PausableUpgradeable,
    AccessControlUpgradeable,
    IDFY_1155,
    ERC1155Upgradeable,
    ERC1155BurnableUpgradeable
{
    using CountersUpgradeable for CountersUpgradeable.Counter;
    using AddressUpgradeable for address;

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
    string public tokenBaseUri;

    // Total NFT_Hard_721 token
    CountersUpgradeable.Counter public totalToken;

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

    function initialize(
        string memory _name,
        string memory _symbol,
        string memory _uri,
        string memory _collectionCID,
        uint256 _defaultRoyaltyRate,
        address payable _owner
    ) public initializer {
        __ERC1155_init("");
        __Pausable_init();
        __ERC1155Burnable_init();
        __UUPSUpgradeable_init();
        _setBaseURI(_uri);

        name = _name;
        symbol = _symbol;

        factory = msg.sender;
        originalCreator = _owner;
        collectionCID = _collectionCID;
        defaultRoyaltyRate = _defaultRoyaltyRate;

        _setupRole(DEFAULT_ADMIN_ROLE, _owner);
        _setupRole(MINTER_ROLE, _owner);
    }

    function signature() external view override returns (bytes4) {
        return type(IDFY_1155).interfaceId;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(
            ERC1155Upgradeable,
            IERC165Upgradeable,
            AccessControlUpgradeable
        )
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _authorizeUpgrade(address)
        internal
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {}

    function _setBaseURI(string memory _newURI) internal {
        require(bytes(_newURI).length > 0, "Blank");
        tokenBaseUri = _newURI;
    }

    function setBaseURI(string memory _newURI)
        external
        override
        whenNotPaused
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _setBaseURI(_newURI);
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function uri(uint256 _tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(bytes(cidOfToken[_tokenId]).length > 0, "Invalid token");

        return
            bytes(tokenBaseUri).length > 0
                ? string(abi.encodePacked(tokenBaseUri, cidOfToken[_tokenId]))
                : "";
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override whenNotPaused {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    function mint(
        address _assetOwner,
        uint256 _amount,
        string memory _cid,
        bytes memory _data,
        uint256 _royaltyRate
    )
        external
        override
        whenNotPaused
        onlyRole(MINTER_ROLE)
        returns (uint256 tokenId)
    {
        // Generate token id
        tokenId = totalToken.current();

        // Add mapping cid of token id token id
        cidOfToken[tokenId] = _cid;

        // Set royalty rate to token
        royaltyRateOfToken[tokenId] = _royaltyRate;

        // Mint token
        _mint(_assetOwner, tokenId, _amount, _data);

        // Update total token
        totalToken.increment();

        return tokenId;
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
