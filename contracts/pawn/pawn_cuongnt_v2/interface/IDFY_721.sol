// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../../../base/BaseInterface.sol";

interface IDFY_721 is 
    BaseInterface
{

    // event
    event CollectionRoyaltyRateChanged(
        uint256 currentRoyaltyRate,
        uint256 newRoyaltyRate
    );

    // function
    function setBaseURI(string memory _newURI) external;

    function mint(
        address _owner,
        string memory _cid,
        uint256 _royaltyRate
    ) external returns (uint256 tokenId);

    function setDefaultRoyaltyRateCollection(
        uint256 _newRoyaltyRate
    ) external;

    function tokenOfOwner(
        address _owner
    ) external view returns (uint256[] memory);

}
