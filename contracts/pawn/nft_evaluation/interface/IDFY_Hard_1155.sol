// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IDFYHard1155 {
    /* ===== Event ===== */
    event CollectionRoyaltyRateChanged(
        uint256 currentRoyaltyRate,
        uint256 newRoyaltyRate
    );

    /* ===== Method ===== */
    function mint(
        address _assetOwner,
        uint256 _amount,
        string memory _cid,
        bytes memory _data,
        uint256 _royaltyRate
    ) external returns (uint256 tokenId);

    function setDefaultRoyaltyRateCollection(uint256 _newRoyaltyRate) external;
}
