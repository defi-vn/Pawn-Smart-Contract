// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/IAccessControlUpgradeable.sol";
import "../../../hub/HubLib.sol";
import "../../../base/BaseContract.sol";
import "../interface/IDFY_1155_Hard_Factory.sol";
import "../implement/DFYHard1155.sol";

contract DFYHard1155Factory is
    Initializable,
    UUPSUpgradeable,
    PausableUpgradeable,
    ERC165Upgradeable,
    IDFYHard1155Factory,
    BaseContract
{
    address hubContract;

    // Mapping collection 1155 of owner
    mapping(address => DFYHard1155[]) public collections1155ByOwner;

    function initialize(address _hubContract) public initializer {
        __Pausable_init();
        __UUPSUpgradeable_init();
        __BaseContract_init(_hubContract);
        hubContract = _hubContract;
    }

    function signature() external pure override returns (bytes4) {
        return type(IDFYHard1155Factory).interfaceId;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC165Upgradeable, IERC165Upgradeable)
        returns (bool)
    {
        return
            interfaceId == type(IDFYHard1155Factory).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function createCollection(
        string memory _name,
        string memory _symbol,
        string memory _collectionCID,
        uint256 _royaltyRate,
        address _evaluationAddress
    ) external override returns (address) {
        require(
            bytes(_name).length > 0 &&
                bytes(_symbol).length > 0 &&
                bytes(_collectionCID).length > 0,
            "Invalid collection"
        );
        DFYHard1155 _newCollection = new DFYHard1155(
            _name,
            _symbol,
            _collectionCID,
            _royaltyRate,
            _evaluationAddress,
            payable(msg.sender)
        );

        collections1155ByOwner[msg.sender].push(_newCollection);
        emit CollectionEvent(
            address(_newCollection),
            msg.sender,
            _name,
            _symbol,
            _collectionCID,
            _royaltyRate,
            CollectionStandard.Collection_Hard_1155,
            CollectionStatus.OPEN
        );
        return address(_newCollection);
    }
}
