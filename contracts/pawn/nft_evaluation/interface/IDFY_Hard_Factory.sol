// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../../../base/BaseInterface.sol";

interface IDFY_Hard_Factory is BaseInterface {
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

    /* ===== Method ===== */
    function createCollection(
        string memory _name,
        string memory _symbol,
        string memory _collectionCID,
        uint256 _royaltyRate,
        address _evaluationAddress
    ) external returns (address newColection);
}
