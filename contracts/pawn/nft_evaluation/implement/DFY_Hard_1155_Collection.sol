// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/IAccessControlUpgradeable.sol";
import "../interface/IDFY_Hard_Collection.sol";
import "../implement/DFY_Hard_1155.sol";
import "../../hub/HubLib.sol";
import "../../../base/BaseContract.sol";

contract DFY_Hard_1155_Collection is
    Initializable,
    UUPSUpgradeable,
    PausableUpgradeable,
    ERC165Upgradeable,
    IDFY_Hard_Collection,
    BaseContract
{
    address hubContract;

    // Mapping collection 1155 of owner
    mapping(address => DFY_Hard_1155[]) public collections1155ByOwner;

    function initialize(address _hubContract) public initializer {
        __Pausable_init();
        __UUPSUpgradeable_init();
        __BaseContract_init(_hubContract);
        hubContract = _hubContract;
    }

    function signature() external view override returns (bytes4) {
        return type(IDFY_Hard_1155).interfaceId;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC165Upgradeable, IERC165Upgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function createCollection(
        string memory _name,
        string memory _symbol,
        string memory _collectionCID,
        uint256 _royaltyRate,
        address _evaluationAddress
    ) external override returns (address newCollection) {
        require(
            bytes(_name).length > 0 &&
                bytes(_symbol).length > 0 &&
                bytes(_collectionCID).length > 0,
            "Invalid collection"
        );
        DFY_Hard_1155 newCollection = new DFY_Hard_1155();
        newCollection.initialize(
            _name,
            _symbol,
            _collectionCID,
            _royaltyRate,
            _evaluationAddress,
            payable(msg.sender)
        );
        collections1155ByOwner[msg.sender].push(newCollection);
        emit CollectionEvent(
            address(newCollection),
            msg.sender,
            _name,
            _symbol,
            _collectionCID,
            _royaltyRate,
            CollectionStandard.Collection_Hard_1155,
            CollectionStatus.OPEN
        );
        return address(newCollection);
    }
}
