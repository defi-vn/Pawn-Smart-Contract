// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../../../hub/HubLib.sol";
import "../../../base/BaseContract.sol";
import "../interface/IDFY_721_Hard_Factory.sol";
import "../implement/DFY_Hard_721.sol";

contract DFYHard721Factory is IDFYHard721Factory, BaseContract {
    /* ===== Enum ===== */
    enum CollectionStatus {
        OPEN
    }

    enum CollectionStandard {
        Collection_Hard_721,
        Collection_Hard_1155
    }

    /* ===== Event ===== */
    event CollectionEvent(
        address collection,
        address owner,
        string name,
        string symbol,
        string collectionCID,
        uint256 royaltyRate,
        CollectionStandard collectionStandard,
        CollectionStatus collectionStatus
    );
    // Mapping collection 721 of owner
    mapping(address => DFYHard721[]) public collections721ByOwner;

    function initialize(address _hubContract) public initializer {
        __BaseContract_init(_hubContract);
    }

    function signature() external pure override returns (bytes4) {
        return type(IDFYHard721Factory).interfaceId;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC165Upgradeable, IERC165Upgradeable)
        returns (bool)
    {
        return
            interfaceId == type(IDFYHard721Factory).interfaceId ||
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
        DFYHard721 _newCollection = new DFYHard721(
            _name,
            _symbol,
            _collectionCID,
            _royaltyRate,
            _evaluationAddress,
            payable(msg.sender)
        );

        collections721ByOwner[msg.sender].push(_newCollection);
        emit CollectionEvent(
            address(_newCollection),
            msg.sender,
            _name,
            _symbol,
            _collectionCID,
            _royaltyRate,
            CollectionStandard.Collection_Hard_721,
            CollectionStatus.OPEN
        );
        return address(_newCollection);
    }
}
