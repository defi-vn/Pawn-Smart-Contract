// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

interface IPawn {

    /** ========================= Collateral ============================= */
    // enum LoanDurationType {WEEK, MONTH}
    // enum CollateralStatus {OPEN, DOING, COMPLETED, CANCEL}

    // struct Collateral {
    //     address owner;
    //     uint256 amount;
    //     address collateralAddress;
    //     address loanAsset;
    //     uint256 expectedDurationQty;
    //     LoanDurationType expectedDurationType;
    //     CollateralStatus status;
    // }

    // enum OfferStatus {PENDING, ACCEPTED, COMPLETED, CANCEL}

    // struct CollateralOfferList {
    //     mapping (uint256 => Offer) offerMapping;
    //     uint256[] offerIdList;
    //     bool isInit;
    // }

    // struct Offer {
    //     address owner;
    //     address repaymentAsset;
    //     uint256 loanAmount;
    //     uint256 interest;
    //     uint256 duration;
    //     OfferStatus status;
    //     LoanDurationType loanDurationType;
    //     LoanDurationType repaymentCycleType;
    //     uint256 liquidityThreshold;
    //     bool isInit;
    // }

    // enum PawnShopPackageStatus {ACTIVE, INACTIVE}
    // enum PawnShopPackageType {AUTO, SEMI_AUTO}
    // struct Range {
    //     uint256 lowerBound;
    //     uint256 upperBound;
    // }

    // struct PawnShopPackage {
    //     address owner;
    //     PawnShopPackageStatus status;
    //     PawnShopPackageType packageType;
    //     address loanToken;
    //     Range loanAmountRange;
    //     address[] collateralAcceptance;
    //     uint256 interest;
    //     uint256 durationType;
    //     Range durationRange;
    //     address repaymentAsset;
    //     LoanDurationType repaymentCycleType;
    //     uint256 loanToValue;
    //     uint256 loanToValueLiquidationThreshold;
    // }

    // enum LoanRequestStatus {PENDING, ACCEPTED, REJECTED, CONTRACTED, CANCEL}
    // struct LoanRequestStatusStruct {
    //     bool isInit;
    //     LoanRequestStatus status;
    // }
    // struct CollateralAsLoanRequestListStruct {
    //     mapping (uint256 => LoanRequestStatusStruct) loanRequestToPawnShopPackageMapping; // Mapping from package to status
    //     uint256[] pawnShopPackageIdList;
    //     bool isInit;
    // }

    // enum ContractStatus {ACTIVE, COMPLETED, DEFAULT}
    // struct ContractTerms {
    //     address borrower;
    //     address lender;
    //     address collateralAsset;
    //     uint256 collateralAmount;
    //     address loanAsset;
    //     uint256 loanAmount;
    //     address repaymentAsset;
    //     uint256 interest;
    //     LoanDurationType repaymentCycleType;
    //     uint256 liquidityThreshold;
    //     uint256 contractStartDate;
    //     uint256 contractEndDate;
    //     uint256 lateThreshold;
    //     uint256 systemFeeRate;
    //     uint256 penaltyRate;
    //     uint256 prepaidFeeRate;
    // }
    // struct Contract {
    //     uint256 collateralId;
    //     int256 offerId;
    //     int256 pawnShopPackageId;
    //     ContractTerms terms;
    //     ContractStatus status;
    //     uint8 lateCount;
    // }

    // enum PaymentRequestStatusEnum {ACTIVE, LATE, COMPLETE, DEFAULT}
    // enum PaymentRequestTypeEnum {INTEREST, OVERDUE, LOAN}
    // struct PaymentRequest {
    //     uint256 requestId;
    //     PaymentRequestTypeEnum paymentRequestType;
    //     uint256 remainingLoan;
    //     uint256 penalty;
    //     uint256 interest;
    //     uint256 remainingPenalty;
    //     uint256 remainingInterest;
    //     uint256 dueDateTimestamp;
    //     bool chargePrepaidFee;
    //     PaymentRequestStatusEnum status;
    // }

    // enum ContractLiquidedReasonType {LATE, RISK, UNPAID}

    /** General functions */

    function emergencyWithdraw(address _token) external;
}