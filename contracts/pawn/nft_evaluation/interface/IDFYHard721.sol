// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "../../../dfy-nft/IDFY721.sol";

interface IDFYHard721 is IDFY721 {
    
    /* ===== Method ===== */
    function safeMint(
        address owner,
        string memory tokenCID
    ) external returns (uint256);
}
