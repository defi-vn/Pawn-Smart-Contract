// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "../pawn-base/IPawnNFTBase.sol";

interface ILoanNFT is IPawnNFTBase {
    /** Events */
    event CollateralEvent_NFT(
        uint256 nftCollateralId,
        NFTCollateral data,
        uint256 UID
    );

    //create offer & cancel
    event OfferEvent_NFT(
        uint256 offerId,
        uint256 nftCollateralId,
        NFTOffer data,
        uint256 UID
    );

    //accept offer
    event LoanContractCreatedEvent_NFT(
        uint256 exchangeRate,
        address fromAddress,
        uint256 contractId,
        NFTLoanContract data,
        uint256 UID
    );

    //repayment
    event PaymentRequestEvent_NFT(
        int256 paymentRequestId,
        uint256 contractId,
        NFTPaymentRequest data
    );

    event RepaymentEvent_NFT(NFTRepaymentEventData repaymentData);

    //liquidity & defaul
    event ContractLiquidedEvent_NFT(NFTContractLiquidationData liquidation);

    event LoanContractCompletedEvent_NFT(uint256 contractId);

    event CancelOfferEvent_NFT(
        uint256 offerId,
        uint256 nftCollateralId,
        address offerOwner,
        uint256 UID
    );

    event CountLateCount(uint256 LateThreshold, uint256 lateCount);

    /** Functions */
    function createContract(
        IPawnNFTBase.NFTContractRawData memory contractData,
        uint256 _UID
    ) external returns (uint256 idx);

    function getContractInfoForReview(uint256 _contractId)
        external
        view
        returns (
            address borrower,
            address lender,
            IEnums.ContractStatus status
        );
}
