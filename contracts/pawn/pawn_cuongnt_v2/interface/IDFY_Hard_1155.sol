// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../../../base/BaseInterface.sol";

interface IDFY_Hard_1155 is BaseInterface {
    function setBaseURI(string memory _newURI) external;

    function mint(
        address _assetOwner,
        address _evaluator,
        uint256 _amount,
        string memory _cid,
        bytes memory _data
    ) external returns (uint256 tokenId);

    function updateCID(uint256 _tokenId, string memory _newCID) external;
}
