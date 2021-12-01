// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import "../interface/IDFY_Hard_1155.sol";
import "../../../base/BaseContract.sol";

contract DFY_Hard_1155 is
    Initializable,
    UUPSUpgradeable,
    PausableUpgradeable,
    AccessControlUpgradeable,
    IDFY_Hard_1155,
    ERC1155Upgradeable,
    ERC1155BurnableUpgradeable,
    BaseContract
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
    string public constant collectionBaseUri =
        "https://defiforyou.mypinata.cloud/ipfs/";

    // Total NFT_Hard_721 token
    CountersUpgradeable.Counter private _totalToken;

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
        string memory _collectionCID,
        uint256 _defaultRoyaltyRate,
        address _evaluationAddress,
        address payable _owner
    ) public initializer {
        __ERC1155_init("");
        __Pausable_init();
        __ERC1155Burnable_init();
        __UUPSUpgradeable_init();

        name = _name;
        symbol = _symbol;

        factory = msg.sender;
        originalCreator = _owner;
        collectionCID = _collectionCID;
        defaultRoyaltyRate = _defaultRoyaltyRate;

        _setupRole(DEFAULT_ADMIN_ROLE, _owner);
        _setupRole(MINTER_ROLE, _owner);
        if (
            _evaluationAddress.isContract() && _evaluationAddress != address(0)
        ) {
            _setupRole(MINTER_ROLE, _evaluationAddress);
        }
    }

    function signature() external view override returns (bytes4) {
        return type(IDFY_Hard_1155).interfaceId;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(
            IERC165Upgradeable,
            ERC165Upgradeable,
            ERC1155Upgradeable,
            AccessControlUpgradeable
        )
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
    ) internal override whenNotPaused {
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
