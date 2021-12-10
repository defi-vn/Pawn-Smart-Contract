// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../../../hub/HubLib.sol";
import "../../../hub/HubInterface.sol";
import "../../../base/BaseContract.sol";
import "../interface/IDFY_721_Hard_Factory.sol";
import "../implement/DFY_Hard_721.sol";

contract DFYHard721Factory is IDFYHard721Factory, BaseContract {
    
    // Mapping collection 721 of owner
    mapping(address => DFYHard721[]) public collections721ByOwner;

    function initialize(address _hub) public initializer {
        __BaseContract_init(_hub);
    }

    /** ==================== Standard interface function implementations ==================== */
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

    function signature() external pure override returns (bytes4) {
        return type(IDFYHard721Factory).interfaceId;
    }

    /** ==================== Create Hard NFT 721 collection ==================== */
    function createCollection(
        string memory name,
        string memory symbol,
        string memory collectionCID,
        uint256 royaltyRate,
        address evaluationAddress
    ) external override returns (address) {
        require(
            bytes(name).length > 0 &&
                bytes(symbol).length > 0 &&
                bytes(collectionCID).length > 0,
            "Invalid collection"
        );
        DFYHard721 _newCollection = new DFYHard721(
            name,
            symbol,
            collectionCID,
            royaltyRate,
            evaluationAddress,
            payable(msg.sender)
        );

        collections721ByOwner[msg.sender].push(_newCollection);

        // add new collection to whitelisted collateral
        HubInterface(contractHub).setWhitelistCollateral_NFT(address(_newCollection), 1);

        emit CollectionEvent(
            address(_newCollection),
            msg.sender,
            name,
            symbol,
            collectionCID,
            royaltyRate,
            CollectionStandard.Collection_Hard_721,
            CollectionStatus.OPEN
        );
        return address(_newCollection);
    }
}
