// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

interface IEnums {
    /** Enums */
    enum LoanDurationType {
        WEEK,
        MONTH
    }

    enum CollateralStatus {
        OPEN,
        DOING,
        COMPLETED,
        CANCEL
    }

    enum OfferStatus {
        PENDING,
        ACCEPTED,
        COMPLETED,
        CANCEL
    }

    enum ContractStatus {
        ACTIVE,
        COMPLETED,
        DEFAULT
    }

    enum PaymentRequestStatusEnum {
        ACTIVE,
        LATE,
        COMPLETE,
        DEFAULT
    }

    enum PaymentRequestTypeEnum {
        INTEREST,
        OVERDUE,
        LOAN
    }

    enum ContractLiquidedReasonType {
        LATE,
        RISK,
        UNPAID
    }

    enum PawnShopPackageStatus {
        ACTIVE,
        INACTIVE
    }

    enum PawnShopPackageType {
        AUTO,
        SEMI_AUTO
    }

    enum LoanRequestStatus {
        PENDING,
        ACCEPTED,
        REJECTED,
        CONTRACTED,
        CANCEL
    }
}