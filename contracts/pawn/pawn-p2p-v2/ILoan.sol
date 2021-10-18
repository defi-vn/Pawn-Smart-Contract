// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "./IPawn.sol";
import "./PawnLib.sol";

interface ILoan is IPawnV2 {
    function createContract(ContractRawData memory _contractData) 
        external 
        returns (uint256 _idx);

    function closePaymentRequestAndStartNew(
        int256 _paymentRequestId,
        uint256 _contractId,
        PaymentRequestTypeEnum _paymentRequestType
    )
        external;

    function checkLenderAccount(
        address collateralAddress,
        uint256 amount,
        uint256 loanToValue,
        address loanToken,
        address repaymentAsset, 
        address owner, 
        address spender
    )
        external 
        view
        returns (
            bool sufficientBalance,
            bool overAllowance
        );
}