// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "../pawn-base/IPawnNFTBase.sol";

interface IPawnNFT is IPawnNFTBase {
    /** Events */
    event CollateralEvent(
        uint256 nftCollateralId,
        IPawnNFTBase.NFTCollateral data,
        string beNFTId
    );

    //create offer & cancel
    event OfferEvent(
        uint256 offerId,
        uint256 nftCollateralId,
        IPawnNFTBase.NFTOffer data
    );

    //accept offer
    event LoanContractCreatedEvent(
        address fromAddress,
        uint256 contractId,
        IPawnNFTBase.NFTLoanContract data
    );

    //repayment
    event PaymentRequestEvent(
        uint256 contractId,
        IPawnNFTBase.NFTPaymentRequest data
    );

    event RepaymentEvent(
        uint256 contractId,
        uint256 paidPenaltyAmount,
        uint256 paidInterestAmount,
        uint256 paidLoanAmount,
        uint256 paidPenaltyFeeAmount,
        uint256 paidInterestFeeAmount,
        uint256 prepaidAmount
    );

    //liquidity & defaul
    event ContractLiquidedEvent(
        uint256 contractId,
        uint256 liquidedAmount,
        uint256 feeAmount,
        IEnums.ContractLiquidedReasonType reasonType
    );

    event LoanContractCompletedEvent(uint256 contractId);

    event CancelOfferEvent(
        uint256 offerId,
        uint256 nftCollateralId,
        address offerOwner
    );
    event RejectOfferEvent(
        uint256 offerId,
        uint256 nftCollateralId,
        address offerOwner
    );

    /** Functions */
    function updateCollateralStatus(
        uint256 collateralId,
        IEnums.CollateralStatus status
    ) external;

    function getInformationNFT(address collectionAddress, uint256 nftId)
        external
        returns (
            address currency,
            uint256 price,
            uint256 depreciationRate
        );
}
