// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

// import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
// import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
// import "../interface/IDFY_Collection.sol";
// import "../implement/DFY_721.sol";
// import "@openzeppelin/contracts-upgradeable/access/IAccessControlUpgradeable.sol";
// import "../../hub/HubLib.sol";

// contract DFY_721_Collection is
//     Initializable,
//     UUPSUpgradeable,
//     PausableUpgradeable,
//     ERC165Upgradeable,
//     IDFY_Collection
// {
//     address hubContract;
//     modifier onlyRoleAdmin() {
//         require(
//             IAccessControlUpgradeable(hubContract).hasRole(
//                 HubRoleLib.DEFAULT_ADMIN_ROLE,
//                 msg.sender
//             )
//         );
//         _;
//     }

//     // Mapping collection 721 of owner
//     mapping(address => DFY_721[]) public collections721ByOwner;

//     function initialize(address _hubContract) public initializer {
//         __Pausable_init();
//         __UUPSUpgradeable_init();
//         hubContract = _hubContract;
//     }

//     function signature() external pure override returns (bytes4) {
//         return type(IDFY_721).interfaceId;
//     }

//     function setContractHub(address _contractHubAddress)
//         external
//         onlyRoleAdmin
//     {
//         hubContract = _contractHubAddress;
//     }

//     function _authorizeUpgrade(address) internal override onlyRoleAdmin {}

//     function supportsInterface(bytes4 interfaceId)
//         public
//         view
//         override(ERC165Upgradeable, IERC165Upgradeable)
//         returns (bool)
//     {
//         return super.supportsInterface(interfaceId);
//     }

//     function pause() external onlyRoleAdmin {
//         _pause();
//     }

//     function unpause() external onlyRoleAdmin {
//         _unpause();
//     }

//     function createCollection(
//         string memory _name,
//         string memory _symbol,
//         string memory _collectionCID,
//         string memory _uri,
//         uint256 _royaltyRate,
//         // address _evaluationAddress
//         CollectionType _collectionType
//     ) external override returns (address newAddressCollection) {
//         require(
//             bytes(_name).length > 0 &&
//                 bytes(_symbol).length > 0 &&
//                 bytes(_uri).length > 0 &&
//                 bytes(_collectionCID).length > 0,
//             "Invalid collection"
//         );
//         if (_collectionType == CollectionType.Collection_Hard) {
//             DFY_721 newAddressCollectionHard = new DFY_721();
//             newAddressCollectionHard.initialize(
//                 _name,
//                 _symbol,
//                 _uri,
//                 _collectionCID,
//                 // _evaluationAddress
//                 0,
//                 payable(msg.sender)
//             );
//             collections721ByOwner[msg.sender].push(newAddressCollectionHard);
//             emit CollectionEvent(
//                 address(newAddressCollectionHard),
//                 msg.sender,
//                 _name,
//                 _symbol,
//                 _collectionCID,
//                 0,
//                 _collectionType,
//                 CollectionStandard.Collection_721,
//                 CollectionStatus.OPEN
//             );
//         } else {
//             DFY_721 newAddressCollectionSoft = new DFY_721();
//             newAddressCollectionSoft.initialize(
//                 _name,
//                 _symbol,
//                 _uri,
//                 _collectionCID,
//                 // _evaluationAddress
//                 _royaltyRate,
//                 payable(msg.sender)
//             );
//             collections721ByOwner[msg.sender].push(newAddressCollectionSoft);
//             emit CollectionEvent(
//                 address(newAddressCollectionSoft),
//                 msg.sender,
//                 _name,
//                 _symbol,
//                 _collectionCID,
//                 _royaltyRate,
//                 _collectionType,
//                 CollectionStandard.Collection_721,
//                 CollectionStatus.OPEN
//             );
//         }

//         return newAddressCollection;
//     }
// }
