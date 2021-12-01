// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.4;

// import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
// import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
// import "../interface/IDFY_Collection.sol";
// import "../implement/DFY_1155.sol";
// import "@openzeppelin/contracts-upgradeable/access/IAccessControlUpgradeable.sol";
// import "../../hub/HubLib.sol";

// contract DFY_1155_Collection is
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

//     // Mapping collection 1155 of owner
//     mapping(address => DFY_1155[]) public collections1155ByOwner;

//     function initialize(address _hubContract) public initializer {
//         __Pausable_init();
//         __UUPSUpgradeable_init();
//         hubContract = _hubContract;
//     }

//     function signature() external pure override returns (bytes4) {
//         return type(IDFY_1155).interfaceId;
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
//             DFY_1155 newAddressCollectionHard = new DFY_1155();
//             newAddressCollectionHard.initialize(
//                 _name,
//                 _symbol,
//                 _uri,
//                 _collectionCID,
//                 0,
//                 payable(msg.sender)
//                 // _evaluationAddress
//             );
//             collections1155ByOwner[msg.sender].push(newAddressCollectionHard);
//             emit CollectionEvent(
//                 address(newAddressCollectionHard),
//                 msg.sender,
//                 _name,
//                 _symbol,
//                 _collectionCID,
//                 0,
//                 _collectionType,
//                 CollectionStandard.Collection_1155,
//                 CollectionStatus.OPEN
//             );
//         } else {
//             DFY_1155 newAddressCollectionSoft = new DFY_1155();
//             newAddressCollectionSoft.initialize(
//                 _name,
//                 _symbol,
//                 _uri,
//                 _collectionCID,
//                 _royaltyRate,
//                 payable(msg.sender)
//                 // _evaluationAddress
//             );
//             collections1155ByOwner[msg.sender].push(newAddressCollectionSoft);
//             emit CollectionEvent(
//                 address(newAddressCollectionSoft),
//                 msg.sender,
//                 _name,
//                 _symbol,
//                 _collectionCID,
//                 _royaltyRate,
//                 _collectionType,
//                 CollectionStandard.Collection_1155,
//                 CollectionStatus.OPEN
//             );
//         }
//         return newAddressCollection;
//     }
// }
