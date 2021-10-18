// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.4;
// import "../pawn-nft/IPawnNFT.sol";
// import "./Exchange.sol";

// contract ExchangeNFT is Exchange
// {
//      // tinh tien lai: interest = loanAmount * interestByLoanDurationType (interestByLoanDurationType = % lãi * số kì * loại kì / (365*100))
//     function calculateInterest (IPawnNFT.Contract memory _contract)
//         external view
//         returns(uint256 interest)
//     {
//         uint256 interestToUSD;
//         uint256 repaymentAssetToUSD;
//         uint256 _interestByLoanDurationType;

//         if(_contract.terms.repaymentCycleType == IPawnNFT.LoanDurationType.WEEK) {   
//             _interestByLoanDurationType = (_contract.terms.interest * 7 * 10**5) / (100*365);
//         } else {  
//             _interestByLoanDurationType = (_contract.terms.interest * 30 * 10**5) / (100*365);
//         }

//         if(_contract.terms.loanAsset == address(0))
//         {
//             interestToUSD = (uint256(Exchange.RateBNBwithUSD())) * 10**10 * _contract.terms.loanAmount;
//         } else {
//             interestToUSD = (uint256(Exchange.getLatesPriceToUSD(_contract.terms.loanAsset))) * 10**10 * _contract.terms.loanAmount;
//         }

//         if(_contract.terms.repaymentAsset == address(0))
//         {
//             repaymentAssetToUSD = (uint256(Exchange.RateBNBwithUSD())) * 10**10;
//         } else {
//             repaymentAssetToUSD = (uint256(Exchange.getLatesPriceToUSD(_contract.terms.repaymentAsset))) * 10**10;
//         }

//         interest = (interestToUSD * _interestByLoanDurationType) / (repaymentAssetToUSD * 10**5);
//     }

//     function calculatePenaltyNFT(
//         IPawnNFT.PaymentRequest memory _paymentrequest,
//         IPawnNFT.Contract memory _contract,
//         uint256 _penaltyRate
//     )
//     external pure
//     returns (uint256 valuePenalty)
//     {
//         uint256 _interestByLoanDurationType;
//         if(_contract.terms.repaymentCycleType == IPawnNFT.LoanDurationType.WEEK) {   
//             _interestByLoanDurationType = (_contract.terms.interest * 7 * 10**5) / (100*365);
//         } else {  
//             _interestByLoanDurationType = (_contract.terms.interest * 30 * 10**5) / (100*365);
//         }

//         valuePenalty = (
//             _paymentrequest.remainingPenalty * 10**5 + 
//             _paymentrequest.remainingPenalty * _interestByLoanDurationType + 
//             _paymentrequest.remainingInterest * _penaltyRate) / 10**5;
//     }

//     function RateAndTimestampNFT(
//         IPawnNFT.Contract memory _contract,
//         address _token
//     )
//     external view 
//     returns (uint256 _collateralExchangeRate, uint256 _loanExchangeRate, uint256 _repaymemtExchangeRate, uint256 _rateUpdateTime)
//     {
//         int priceCollateral;
//         int priceLoan;
//         int priceRepayment;

//         if(_token == address(0)) {
//             (priceCollateral,_rateUpdateTime) = RateBNBwithUSDAttimestamp();
//         } else {
//             (priceCollateral,_rateUpdateTime) = getRateAndTimestamp(_token);
//         }
//         _collateralExchangeRate = uint256(priceCollateral) * 10 ** 10;

//         if(_contract.terms.loanAsset == address(0)) {
//             (priceLoan,_rateUpdateTime) = RateBNBwithUSDAttimestamp();
//         } else {
//             (priceLoan,_rateUpdateTime) = getRateAndTimestamp(_contract.terms.loanAsset);
//         }
//         _loanExchangeRate = uint256(priceLoan) * 10 ** 10;

//         if(_contract.terms.repaymentAsset == address(0)) {
//             (priceRepayment,_rateUpdateTime) = RateBNBwithUSDAttimestamp();
//         } else {
//             (priceRepayment,_rateUpdateTime) = getRateAndTimestamp(_contract.terms.repaymentAsset);
//         }
//         _repaymemtExchangeRate = uint256(priceRepayment) * 10**10;
//     }
// }
