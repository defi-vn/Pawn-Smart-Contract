// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../../../hub/HubLib.sol";
import "../../../base/BaseContract.sol";
import "../interface/IDFY_Hard_Factory.sol";
import "../implement/DFY_Hard_721.sol";

contract DFY_Hard_721_Factory is IDFY_Hard_Factory, BaseContract {
    // Mapping collection 721 of owner
    mapping(address => DFY_Hard_721[]) public collections721ByOwner;

    function initialize(address _hubContract) public initializer {
        __BaseContract_init(_hubContract);
    }

    function signature() external pure override returns (bytes4) {
        return type(IDFY_Hard_Factory).interfaceId;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC165Upgradeable, IERC165Upgradeable)
        returns (bool)
    {
        return
            interfaceId == type(IDFY_Hard_Factory).interfaceId ||
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
        DFY_Hard_721 _newCollection = new DFY_Hard_721(
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
