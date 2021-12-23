// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "../pawn-base/IPawnNFTBase.sol";

interface IPawnNFT is IPawnNFTBase {
    /** Events */
    event CollateralEvent_NFT(
        uint256 nftCollateralId,
        IPawnNFTBase.NFTCollateral data,
        string beNFTId
    );

    //create offer & cancel
    event OfferEvent_NFT(
        uint256 offerId,
        uint256 nftCollateralId,
        IPawnNFTBase.NFTOffer data
    );

    //accept offer
    event LoanContractCreatedEvent_NFT(
        address fromAddress,
        uint256 contractId,
        IPawnNFTBase.NFTLoanContract data
    );

    //repayment
    event PaymentRequestEvent_NFT(
        uint256 contractId,
        IPawnNFTBase.NFTPaymentRequest data
    );

    event RepaymentEvent_NFT(
        uint256 contractId,
        uint256 paidPenaltyAmount,
        uint256 paidInterestAmount,
        uint256 paidLoanAmount,
        uint256 paidPenaltyFeeAmount,
        uint256 paidInterestFeeAmount,
        uint256 prepaidAmount
    );

    //liquidity & defaul
    event ContractLiquidedEvent_NFT(
        uint256 contractId,
        uint256 liquidedAmount,
        uint256 feeAmount,
        IEnums.ContractLiquidedReasonType reasonType
    );

    event LoanContractCompletedEvent_NFT(uint256 contractId);

    event CancelOfferEvent_NFT(
        uint256 offerId,
        uint256 nftCollateralId,
        address offerOwner
    );

    /** Functions */
    function updateCollateralStatus(
        uint256 collateralId,
        IEnums.CollateralStatus status
    ) external;
}
