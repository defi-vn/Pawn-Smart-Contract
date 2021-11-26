// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../../../base/BaseInterface.sol";

interface IDFY_Collection is BaseInterface {
    // enum type
    enum CollectionStatus {
        OPEN
    }

    enum CollectionType {
        Collection_Hard,
        Collection_Soft
    }

    enum CollectionStandard {
        Collection_721,
        Collection_1155
    }

    // event
    event CollectionEvent(
        address collection,
        address owner,
        string name,
        string symbol,
        string collectionCID,
        uint256 royaltyRate,
        CollectionType collectionType,
        CollectionStandard collectionStandard,
        CollectionStatus collectionStatus
    );

    // function
    function createCollection(
        string memory _name,
        string memory _symbol,
        string memory _collectionCID,
        string memory _uri,
        uint256 _royaltyRate,
        // address _evaluationAddress
        CollectionType _collectionType
    ) external returns (address newAddressCollection);
}
