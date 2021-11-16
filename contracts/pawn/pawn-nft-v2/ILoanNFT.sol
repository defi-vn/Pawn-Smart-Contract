// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;
import "./PawnNFTLib.sol";

interface ILoanNFT {
    function updateCollateralStatus(
        uint256 _collateralId,
        CollateralStatus_NFT _status
    ) external;
}
