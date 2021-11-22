// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../../../base/BaseInterface.sol";

interface IDFY_Hard_721 is BaseInterface {
    function setBaseURI(string memory _newURI) external;

    function mint(
        address _evaluator,
        address _owner,
        string memory _cid
    ) external returns (uint256 tokenId);

    function updateCID(uint256 _tokenId, string memory _newCID) external;
}
