// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IDFYHard721 {
    /* ===== Event ===== */
    event CollectionRoyaltyRateChanged(
        uint256 currentRoyaltyRate,
        uint256 newRoyaltyRate
    );

    /* ===== Method ===== */
    function mint(
        address _owner,
        string memory _cid,
        uint256 _royaltyRate
    ) external returns (uint256 tokenId);

    function setDefaultRoyaltyRateCollection(uint256 _newRoyaltyRate) external;

    function tokenOfOwner(address _owner)
        external
        view
        returns (uint256[] memory);
}
