// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

interface IPawnV2 {

    /** General functions */

    function emergencyWithdraw(address _token) external;
}