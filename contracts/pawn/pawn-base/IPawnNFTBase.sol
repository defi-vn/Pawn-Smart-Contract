// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "../../base/BaseInterface.sol";
import "./IEnums.sol";

interface IPawnNFTBase is BaseInterface {
    /** Datatypes */
    struct NFTCollateral {
        address owner;
        address nftContract;
        uint256 nftTokenId;
        uint256 loanAmount;
        address loanAsset;
        uint256 nftTokenQuantity;
        uint256 expectedDurationQty;
        IEnums.LoanDurationType durationType;
        IEnums.CollateralStatus status;
    }

    struct NFTCollateralOfferList {
        //offerId => Offer
        mapping(uint256 => NFTOffer) offerMapping;
        uint256[] offerIdList;
        bool isInit;
    }

    struct NFTOffer {
        address owner;
        address repaymentAsset;
        uint256 loanToValue;
        uint256 loanAmount;
        uint256 interest;
        uint256 duration;
        IEnums.OfferStatus status;
        IEnums.LoanDurationType loanDurationType;
        IEnums.LoanDurationType repaymentCycleType;
        uint256 liquidityThreshold;
    }

    struct NFTLoanContractTerms {
        address borrower;
        address lender;
        uint256 nftTokenId;
        address nftCollateralAsset;
        uint256 nftCollateralAmount;
        address loanAsset;
        uint256 loanAmount;
        address repaymentAsset;
        uint256 interest;
        IEnums.LoanDurationType repaymentCycleType;
        uint256 liquidityThreshold;
        uint256 contractStartDate;
        uint256 contractEndDate;
        uint256 lateThreshold;
        uint256 systemFeeRate;
        uint256 penaltyRate;
        uint256 prepaidFeeRate;
    }

    struct NFTLoanContract {
        uint256 nftCollateralId;
        uint256 offerId;
        NFTLoanContractTerms terms;
        IEnums.ContractStatus status;
        uint8 lateCount;
    }

    struct NFTPaymentRequest {
        uint256 requestId;
        IEnums.PaymentRequestTypeEnum paymentRequestType;
        uint256 remainingLoan;
        uint256 penalty;
        uint256 interest;
        uint256 remainingPenalty;
        uint256 remainingInterest;
        uint256 dueDateTimestamp;
        bool chargePrepaidFee;
        IEnums.PaymentRequestStatusEnum status;
    }

    struct NFTContractRawData {
        uint256 nftCollateralId;
        NFTCollateral collateral;
        uint256 offerId;
        uint256 loanAmount;
        address lender;
        address repaymentAsset;
        uint256 interest;
        IEnums.LoanDurationType repaymentCycleType;
        uint256 liquidityThreshold;
        uint256 exchangeRate;
    }

    struct NFTContractLiquidationData {
        uint256 contractId;
        uint256 tokenEvaluationExchangeRate;
        uint256 loanExchangeRate;
        uint256 repaymentExchangeRate;
        uint256 rateUpdateTime;
        IEnums.ContractLiquidedReasonType reasonType;
    }

    struct NFTRepaymentEventData {
        uint256 contractId;
        uint256 paidPenaltyAmount;
        uint256 paidInterestAmount;
        uint256 paidLoanAmount;
        uint256 paidPenaltyFeeAmount;
        uint256 paidInterestFeeAmount;
        uint256 prepaidAmount;
        uint256 requestId;
        uint256 UID;
    }
}