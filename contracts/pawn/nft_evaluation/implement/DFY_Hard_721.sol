// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import "../interface/IDFY_Hard_721.sol";
import "../../../base/BaseContract.sol";

contract DFY_Hard_721 is
    Initializable,
    UUPSUpgradeable,
    PausableUpgradeable,
    AccessControlUpgradeable,
    BaseContract,
    IDFY_Hard_721,
    ERC721Upgradeable,
    ERC721EnumerableUpgradeable,
    ERC721URIStorageUpgradeable,
    ERC721BurnableUpgradeable
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
    string public constant collectionBaseUri = "https://defiforyou.mypinata.cloud/ipfs/";

    // Total NFT_Hard_721 token
    CountersUpgradeable.Counter private _totalToken;

    // Mapping token to CID
    // TokenId => CID
    mapping(uint256 => string) public cidOfToken;

    // Mapping token id to royalty rate
    // Token id => royalty rate
    mapping(uint256 => uint256) public royaltyRateOfToken;

    function initialize(
        string memory _name,
        string memory _symbol,
        string memory _collectionCID,
        uint256 _defaultRoyaltyRate,
        address _evaluationAddress,
        address payable _owner
    ) public initializer {
        __ERC721_init(_name, _symbol);
        __Pausable_init();
        __UUPSUpgradeable_init();

        factory = msg.sender;
        originalCreator = _owner;
        collectionCID = _collectionCID;
        defaultRoyaltyRate = _defaultRoyaltyRate;

        _setupRole(DEFAULT_ADMIN_ROLE, _owner);
        _setupRole(MINTER_ROLE, _owner);

        if(_evaluationAddress.isContract() && _evaluationAddress!=address(0)){
            _setupRole(MINTER_ROLE, _evaluationAddress);
        }
    }

    function signature() external view override returns (bytes4) {
        return type(IDFY_Hard_721).interfaceId;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override
    (
        ERC721Upgradeable,
        ERC721EnumerableUpgradeable,
        AccessControlUpgradeable,
        ERC165Upgradeable,
        IERC165Upgradeable
    )
        returns (bool)
    {
        return
            interfaceId == type(IDFY_Hard_721).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function collectionURI() public view returns (string memory) {
        return string(abi.encodePacked(_baseURI(), collectionCID));
    }

    function _baseURI() internal pure override returns (string memory) {
        return collectionBaseUri;
    }

    function mint(
        address _owner,
        string memory _cid,
        uint256 _royaltyRate
    )
        external
        override
        whenNotPaused
        onlyRole(MINTER_ROLE)
        returns (uint256 tokenId)
    {
        // Generate token id
        tokenId = _totalToken.current();

        // Add mapping cid of token id token id
        cidOfToken[tokenId] = _cid;

        // Set royalty rate to token
        royaltyRateOfToken[tokenId] = _royaltyRate;

        // Mint token
        _safeMint(_owner, tokenId);

        // Update total token
        _totalToken.increment();

        return tokenId;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721Upgradeable, ERC721EnumerableUpgradeable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId)
        internal
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
    {
        super._burn(tokenId);
    }

    function tokenOfOwner(address _owner)
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

    function setDefaultRoyaltyRateCollection(uint256 _newRoyaltyRate)
        external
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        uint256 currentRoyaltyRate = defaultRoyaltyRate;

        defaultRoyaltyRate = _newRoyaltyRate;

        emit CollectionRoyaltyRateChanged(currentRoyaltyRate, _newRoyaltyRate);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }
}
