// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "../pawn-base/IPawnNFTBase.sol";

interface IPawnNFT is IPawnNFTBase {
    
    function updateCollateralStatus(
        uint256 collateralId,
        IEnums.CollateralStatus status
    ) external;
}
