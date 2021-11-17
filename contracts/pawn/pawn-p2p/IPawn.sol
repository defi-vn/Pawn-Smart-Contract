// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "../pawn-p2p-v2/PawnLib.sol";

interface IPawn {
    /** General functions */

    function emergencyWithdraw(address _token) external;

    function updateCollateralStatus(
        uint256 _collateralId,
        CollateralStatus _status
    ) external;

    function updateCollateralAmount(uint256 _collateralId, uint256 _amount)
        external;

    function getContractInfoForReview(uint256 _contractId)
        external
        view
        returns (
            address borrower,
            address lender,
            ContractStatus status
        );
}
