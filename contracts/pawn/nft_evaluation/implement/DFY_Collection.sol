// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import "../interface/IDFY_Collection.sol";
import "../implement/DFY_721.sol";
import "../implement/DFY_1155.sol";
import "@openzeppelin/contracts-upgradeable/access/IAccessControlUpgradeable.sol";
import "../../hub/HubLib.sol";

contract DFY_Collection is
    Initializable,
    UUPSUpgradeable,
    PausableUpgradeable,
    ERC165Upgradeable,
    IDFY_Collection
{
    address hubContract;
    modifier onlyRoleAdmin() {
        require(
            IAccessControlUpgradeable(hubContract).hasRole(
                HubRoleLib.DEFAULT_ADMIN_ROLE,
                msg.sender
            )
        );
        _;
    }

    // Mapping collection 721 of owner
    mapping(address => DFY_721[]) public collections721ByOwner;

    // Mapping collection 1155 of owner
    mapping(address => DFY_1155[]) public collections1155ByOwner;

    function initialize(
        string memory _name,
        string memory _symbol,
        string memory _uri,
        address _hubContract
    ) public initializer {
        __Pausable_init();
        __UUPSUpgradeable_init();
        hubContract = _hubContract;
    }

    function signature() external view override returns (bytes4) {
        return type(IDFY_721).interfaceId;
    }

    function setContractHub(address _contractHubAddress)
        external
        onlyRoleAdmin
    {
        hubContract = _contractHubAddress;
    }

    function _authorizeUpgrade(address) internal override onlyRoleAdmin {}

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC165Upgradeable, IERC165Upgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function pause() external onlyRoleAdmin {
        _pause();
    }

    function unpause() external onlyRoleAdmin {
        _unpause();
    }

    function createCollection(
        string memory _name,
        string memory _symbol,
        string memory _collectionCID,
        string memory _uri,
        uint256 _royaltyRate,
        CollectionType _collectionType,
        CollectionStandard _collectionStandard
    ) external override returns (address newAddressCollection) {
        require(
            bytes(_name).length > 0 &&
                bytes(_symbol).length > 0 &&
                bytes(_uri).length > 0 &&
                bytes(_collectionCID).length > 0,
            "Invalid collection"
        );

        if (_collectionStandard == CollectionStandard.Collection_721) {
            if (_collectionType == CollectionType.Collection_Hard) {
                DFY_721 newCollection721 = new DFY_721();
                newCollection721.initialize(
                    _name,
                    _symbol,
                    _uri,
                    _collectionCID,
                    0,
                    payable(msg.sender)
                );
                collections721ByOwner[msg.sender].push(newCollection721);
                emit CollectionEvent(
                    address(newCollection721),
                    msg.sender,
                    _name,
                    _symbol,
                    _collectionCID,
                    0,
                    _collectionType,
                    _collectionStandard,
                    CollectionStatus.OPEN
                );
            } else {
                DFY_721 newCollection721 = new DFY_721();
                newCollection721.initialize(
                    _name,
                    _symbol,
                    _uri,
                    _collectionCID,
                    _royaltyRate,
                    payable(msg.sender)
                );
                collections721ByOwner[msg.sender].push(newCollection721);
                emit CollectionEvent(
                    address(newCollection721),
                    msg.sender,
                    _name,
                    _symbol,
                    _collectionCID,
                    _royaltyRate,
                    _collectionType,
                    _collectionStandard,
                    CollectionStatus.OPEN
                );
            }
        } else {
            if (_collectionType == CollectionType.Collection_Hard) {
                DFY_1155 newCollection1155 = new DFY_1155();
                newCollection1155.initialize(
                    _name,
                    _symbol,
                    _uri,
                    _collectionCID,
                    0,
                    payable(msg.sender)
                );
                collections1155ByOwner[msg.sender].push(newCollection1155);
                emit CollectionEvent(
                    address(newCollection1155),
                    msg.sender,
                    _name,
                    _symbol,
                    _collectionCID,
                    0,
                    _collectionType,
                    _collectionStandard,
                    CollectionStatus.OPEN
                );
            } else {
                DFY_1155 newCollection1155 = new DFY_1155();
                newCollection1155.initialize(
                    _name,
                    _symbol,
                    _uri,
                    _collectionCID,
                    _royaltyRate,
                    payable(msg.sender)
                );
                collections1155ByOwner[msg.sender].push(newCollection1155);
                emit CollectionEvent(
                    address(newCollection1155),
                    msg.sender,
                    _name,
                    _symbol,
                    _collectionCID,
                    _royaltyRate,
                    _collectionType,
                    _collectionStandard,
                    CollectionStatus.OPEN
                );
            }
        }
    }
}
