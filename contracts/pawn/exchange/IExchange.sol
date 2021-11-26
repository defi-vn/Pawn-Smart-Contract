// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;
import "../../base/BaseInterface.sol";
import "../pawn-nft-v2/PawnNFTLib.sol";
import "../pawn-p2p-v2/PawnLib.sol";

interface IExchange is BaseInterface {
    // lay gia cua dong BNB

    function setCryptoExchange(
        address _cryptoAddress,
        address _latestPriceAddress
    ) external;

    function calculateLoanAmountAndExchangeRate(
        Collateral memory _col,
        PawnShopPackage memory _pkg
    ) external view returns (uint256 loanAmount, uint256 exchangeRate);

    function calcLoanAmountAndExchangeRate(
        address collateralAddress,
        uint256 amount,
        address loanAsset,
        uint256 loanToValue,
        address repaymentAsset
    )
        external
        view
        returns (
            uint256 loanAmount,
            uint256 exchangeRate,
            uint256 collateralToUSD,
            uint256 rateLoanAsset,
            uint256 rateRepaymentAsset
        );

    function exchangeRateofOffer(address _adLoanAsset, address _adRepayment)
        external
        view
        returns (uint256 exchangeRateOfOffer);

    function calculateInterest(
        uint256 _remainingLoan,
        Contract memory _contract
    ) external view returns (uint256 interest);

    function calculatePenalty(
        PaymentRequest memory _paymentrequest,
        Contract memory _contract,
        uint256 _penaltyRate
    ) external pure returns (uint256 valuePenalty);

    function RateAndTimestamp(Contract memory _contract)
        external
        view
        returns (
            uint256 _collateralExchangeRate,
            uint256 _loanExchangeRate,
            uint256 _repaymemtExchangeRate,
            uint256 _rateUpdateTime
        );

    function collateralPerRepaymentAndLoanTokenExchangeRate(
        Contract memory _contract
    )
        external
        view
        returns (
            uint256 _collateralPerRepaymentTokenExchangeRate,
            uint256 _collateralPerLoanAssetExchangeRate
        );

    function exchangeRateOfOffer_NFT(address _adLoanAsset, address _adRepayment)
        external
        view
        returns (uint256 exchangeRate);

    function calculateInterest_NFT(
        uint256 _remainingLoan,
        Contract_NFT memory _contract
    ) external view returns (uint256 interest);

    function calculatePenalty_NFT(
        PaymentRequest_NFT memory _paymentrequest,
        Contract_NFT memory _contract,
        uint256 _penaltyRate
    ) external pure returns (uint256 valuePenalty);

    function collateralPerRepaymentAndLoanTokenExchangeRate_NFT(
        Contract_NFT memory _contract,
        address _adEvaluationAsset
    )
        external
        view
        returns (
            uint256 _collateralPerRepaymentTokenExchangeRate,
            uint256 _collateralPerLoanAssetExchangeRate
        );

    function RateAndTimestamp_NFT(
        Contract_NFT memory _contract,
        address _adEvaluationAsset
    )
        external
        view
        returns (
            uint256 _collateralExchangeRate,
            uint256 _loanExchangeRate,
            uint256 _repaymemtExchangeRate,
            uint256 _rateUpdateTime
        );
}
