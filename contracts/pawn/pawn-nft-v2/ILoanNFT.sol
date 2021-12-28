// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "../pawn-base/IPawnNFTBase.sol";

interface ILoanNFT is IPawnNFTBase {
    /** Events */
    event CollateralEvent(
        uint256 nftCollateralId,
        NFTCollateral data,
        string beNFTId
    );

    //create offer & cancel
    event OfferEvent(uint256 offerId, uint256 nftCollateralId, NFTOffer data);

    //accept offer
    event LoanContractCreatedEvent(
        uint256 exchangeRate,
        address fromAddress,
        uint256 contractId,
        NFTLoanContract data
    );

    //repayment
    event PaymentRequestEvent(
        int256 paymentRequestId,
        uint256 contractId,
        NFTPaymentRequest data
    );

    event RepaymentEvent(NFTRepaymentEventData repaymentData);

    //liquidity & defaul
    event ContractLiquidedEvent(NFTContractLiquidationData liquidation);

    event LoanContractCompletedEvent(uint256 contractId);

    event CancelOfferEvent(
        uint256 offerId,
        uint256 nftCollateralId,
        address offerOwner
    );

    event CountLateCount(uint256 LateThreshold, uint256 lateCount);

    /** Functions */
    function createContract(IPawnNFTBase.NFTContractRawData memory contractData)
        external
        returns (uint256 idx);

    function getContractInfoForReview(uint256 _contractId)
        external
        view
        returns (
            address borrower,
            address lender,
            IEnums.ContractStatus status
        );
}
