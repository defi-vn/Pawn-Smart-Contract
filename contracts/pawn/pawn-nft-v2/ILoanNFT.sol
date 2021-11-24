// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;
import "./PawnNFTLib.sol";
import "../../base/BaseInterface.sol";

interface ILoanNFT is BaseInterface {
    function updateCollateralStatus(
        uint256 _collateralId,
        CollateralStatus_NFT _status
    ) external;
}
