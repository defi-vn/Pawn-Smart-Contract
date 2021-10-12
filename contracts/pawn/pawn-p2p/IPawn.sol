// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "./PawnLib.sol";

interface IPawn {
    /** General functions */

    function emergencyWithdraw(address _token) external;

    function updateCollateralStatus(
        uint256 _collateralId,
        CollateralStatus _status
    ) external;
}