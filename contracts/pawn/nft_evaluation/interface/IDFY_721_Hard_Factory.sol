// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../../../base/BaseInterface.sol";

interface IDFYHard721Factory is BaseInterface {
    /* ===== Method ===== */
    function createCollection(
        string memory _name,
        string memory _symbol,
        string memory _collectionCID,
        uint256 _royaltyRate,
        address _evaluationAddress
    ) external returns (address newColection);
}
