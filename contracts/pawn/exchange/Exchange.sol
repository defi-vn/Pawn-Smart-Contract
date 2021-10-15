// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import "../pawn-p2p-v2/PawnLib.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "../pawn-nft/IPawnNFT.sol";

contract Exchange is Initializable, UUPSUpgradeable, AccessControlUpgradeable {
    
    mapping(address => address) public ListCryptoExchange;

    function initialize() public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function _authorizeUpgrade(address)
        internal
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {}

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    // set dia chi cac token ( crypto) tuong ung voi dia chi chuyen doi ra USD tren chain link
    function setCryptoExchange(
        address _cryptoAddress,
        address _latestPriceAddress
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        ListCryptoExchange[_cryptoAddress] = _latestPriceAddress;
    }

    // lay gia cua dong BNB
    function RateBNBwithUSD() internal view returns (int256 price) {
        AggregatorV3Interface getPriceToUSD = AggregatorV3Interface(
            0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526
        );
        (, price, , , ) = getPriceToUSD.latestRoundData();
    }

    // lay ti gia dong BNB + timestamp
    function RateBNBwithUSDAttimestamp()
        internal
        view
        returns (int256 price, uint256 timeStamp)
    {
        AggregatorV3Interface getPriceToUSD = AggregatorV3Interface(
            0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526
        );
        (, price, , timeStamp, ) = getPriceToUSD.latestRoundData();
    }

    // lay gia cua cac crypto va token khac da duoc them vao ListcryptoExchange
    function getLatesPriceToUSD(address _adcrypto)
        internal
        view
        returns (int256 price)
    {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            ListCryptoExchange[_adcrypto]
        );
        (, price, , , ) = priceFeed.latestRoundData();
    }

    // lay ti gia va timestamp cua cac crypto va token da duoc them vao ListcryptoExchange
    function getRateAndTimestamp(address _adcrypto)
        internal
        view
        returns (int256 price, uint256 timeStamp)
    {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            ListCryptoExchange[_adcrypto]
        );
        (, price, , timeStamp, ) = priceFeed.latestRoundData();
    }

    // loanAmount= (CollateralAsset * amount * loanToValue) / RateLoanAsset
    // exchangeRate = RateLoanAsset / RateRepaymentAsset
    function calculateLoanAmountAndExchangeRate(
        Collateral memory _col,
        PawnShopPackage memory _pkg
    ) external view returns (uint256 loanAmount, uint256 exchangeRate) {
        uint256 collateralToUSD;
        uint256 rateLoanAsset;
        uint256 rateRepaymentAsset;

        if (_col.collateralAddress == address(0)) {
            // If collateral address is address(0), check BNB exchange rate with USD
            // collateralToUSD = (uint256(RateBNBwithUSD()) * 10**10 * _pkg.loanToValue * _col.amount) / 100;
            (, uint256 _ltvAmount)  = SafeMathUpgradeable.tryMul(_pkg.loanToValue, _col.amount);
            (, uint256 _collRate)   = SafeMathUpgradeable.tryMul(_ltvAmount, uint256(RateBNBwithUSD()));
            (, uint256 _collToUSD)  = SafeMathUpgradeable.tryDiv(_collRate, (100 * 10**5));

            collateralToUSD = _collToUSD;
        } else {
            // If collateral address is not BNB, get latest price in USD of collateral crypto
            // collateralToUSD = (uint256(getLatesPriceToUSD(_col.collateralAddress)) * 10**10 * _pkg.loanToValue * _col.amount) / 100;
            (, uint256 _ltvAmount)  = SafeMathUpgradeable.tryMul(_pkg.loanToValue, _col.amount);
            (, uint256 _collRate)   = SafeMathUpgradeable.tryMul(_ltvAmount, uint256(getLatesPriceToUSD(_col.collateralAddress)));
            (, uint256 _collToUSD)  = SafeMathUpgradeable.tryDiv(_collRate, (100 * 10**5));

            collateralToUSD = _collToUSD;
        }
        
        if (_col.loanAsset == address(0)) {
            // get price of BNB in USD
            rateLoanAsset = uint256(RateBNBwithUSD());
        } else {
            // get price in USD of crypto as loan asset
            rateLoanAsset = uint256(getLatesPriceToUSD(_col.loanAsset));
        }

        // Calculate Loan amount
        (, uint256 _loanAmount) = SafeMathUpgradeable.tryDiv(collateralToUSD, rateLoanAsset); 
        loanAmount = _loanAmount;

        if (_pkg.repaymentAsset == address(0)) {
            // get price in USD of BNB as repayment asset 
            rateRepaymentAsset = uint256(RateBNBwithUSD());
        } else {
            // get latest price in USD of crypto as repayment asset
            rateRepaymentAsset = uint256(getLatesPriceToUSD(_pkg.repaymentAsset));
        }

        // calculate exchange rate
        (, uint256 _exchange) = SafeMathUpgradeable.tryDiv(rateLoanAsset, rateRepaymentAsset);
        exchangeRate = _exchange;
    }

    function calcLoanAmountAndExchangeRate(
        address collateralAddress,
        uint256 amount,
        address loanAsset,
        uint256 loanToValue,
        address repaymentAsset
    ) external view returns (
        uint256 loanAmount, 
        uint256 exchangeRate, 
        uint256 collateralToUSD, 
        uint256 rateLoanAsset,
        uint256 rateRepaymentAsset) {

        if (collateralAddress == address(0)) {
            // If collateral address is address(0), check BNB exchange rate with USD
            // collateralToUSD = (uint256(RateBNBwithUSD()) * loanToValue * amount) / (100 * 10**5);
            (, uint256 ltvAmount)  = SafeMathUpgradeable.tryMul(loanToValue, amount);
            (, uint256 collRate)   = SafeMathUpgradeable.tryMul(ltvAmount, uint256(RateBNBwithUSD()));
            (, uint256 collToUSD)  = SafeMathUpgradeable.tryDiv(collRate, (100 * 10**5));

            collateralToUSD = collToUSD;
        } else {
            // If collateral address is not BNB, get latest price in USD of collateral crypto
            // collateralToUSD = (uint256(getLatesPriceToUSD(collateralAddress))  * loanToValue * amount) / (100 * 10**5);
            (, uint256 ltvAmount)  = SafeMathUpgradeable.tryMul(loanToValue, amount);
            (, uint256 collRate)   = SafeMathUpgradeable.tryMul(ltvAmount, uint256(getLatesPriceToUSD(collateralAddress)));
            (, uint256 collToUSD)  = SafeMathUpgradeable.tryDiv(collRate, (100 * 10**5));

            collateralToUSD = collToUSD;
        }

        if (loanAsset == address(0)) {
            // get price of BNB in USD
            rateLoanAsset = uint256(RateBNBwithUSD());
        } else {
            // get price in USD of crypto as loan asset
            rateLoanAsset = uint256(getLatesPriceToUSD(loanAsset));
        }

        (, uint256 lAmount) = SafeMathUpgradeable.tryDiv(collateralToUSD, rateLoanAsset); 
        // loanAmount = collateralToUSD / rateLoanAsset;
        loanAmount = lAmount;

        if (repaymentAsset == address(0)) {
            // get price in USD of BNB as repayment asset 
            rateRepaymentAsset = uint256(RateBNBwithUSD());
        } else {
            // get latest price in USD of crypto as repayment asset
            rateRepaymentAsset = uint256(getLatesPriceToUSD(repaymentAsset));
        }

        // calculate exchange rate
        (, uint256 xchange) = SafeMathUpgradeable.tryDiv(rateLoanAsset, rateRepaymentAsset);
        exchangeRate = xchange;
    }

    function exchangeRateofOffer(address _adLoanAsset, address _adRepayment)
        external
        view
        returns (uint256 exchangeRateOfOffer)
    {
        if (_adLoanAsset == address(0)) {
            exchangeRateOfOffer =
                (uint256(RateBNBwithUSD()) * 10**10) /
                (uint256(getLatesPriceToUSD(_adRepayment)) * 10**10);
        } else if (_adRepayment == address(0)) {
            exchangeRateOfOffer =
                (uint256(getLatesPriceToUSD(_adLoanAsset)) * 10**10) /
                (uint256(RateBNBwithUSD()) * 10**10);
        } else {
            exchangeRateOfOffer =
                (uint256(getLatesPriceToUSD(_adLoanAsset)) * 10**10) /
                (uint256(getLatesPriceToUSD(_adRepayment)) * 10**10);
        }
    }

    // tinh tien lai: interest = loanAmount * interestByLoanDurationType (interestByLoanDurationType = % lãi * số kì * loại kì / (365*100))
    function calculateInterest(Contract memory _contract)
        external
        view
        returns (uint256 interest)
    {
        uint256 interestToUSD;
        uint256 repaymentAssetToUSD;
        uint256 _interestByLoanDurationType;

        if (_contract.terms.repaymentCycleType == LoanDurationType.WEEK) {
            _interestByLoanDurationType =
                (_contract.terms.interest * 7 * 10**5) /
                (100 * 365);
        } else {
            _interestByLoanDurationType =
                (_contract.terms.interest * 30 * 10**5) /
                (100 * 365);
        }

        if (_contract.terms.loanAsset == address(0)) {
            interestToUSD = (uint256(RateBNBwithUSD()) *
                10**10 *
                _contract.terms.loanAmount);
        } else {
            interestToUSD = (uint256(
                getLatesPriceToUSD(_contract.terms.loanAsset)
            ) *
                10**10 *
                _contract.terms.loanAmount);
        }

        if (_contract.terms.repaymentAsset == address(0)) {
            repaymentAssetToUSD = uint256(RateBNBwithUSD()) * 10**10;
        } else {
            repaymentAssetToUSD =
                uint256(getLatesPriceToUSD(_contract.terms.loanAsset)) *
                10**10;
        }

        interest =
            (interestToUSD * _interestByLoanDurationType) /
            (repaymentAssetToUSD * 10**10);
    }

    // tinh penalty
    function calculatePenalty(
        PaymentRequest memory _paymentrequest,
        Contract memory _contract,
        uint256 _penaltyRate
    ) external pure returns (uint256 valuePenalty) {
        uint256 _interestByLoanDurationType;
        if (_contract.terms.repaymentCycleType == LoanDurationType.WEEK) {
            _interestByLoanDurationType =
                (_contract.terms.interest * 7 * 10**5) /
                (100 * 365);
        } else {
            _interestByLoanDurationType =
                (_contract.terms.interest * 30 * 10**5) /
                (100 * 365);
        }

        valuePenalty =
            (_paymentrequest.remainingPenalty *
                10**5 +
                _paymentrequest.remainingPenalty *
                _interestByLoanDurationType +
                _paymentrequest.remainingInterest *
                _penaltyRate) /
            10**10;
    }

    // lay Rate va thoi gian cap nhat ti gia do
    function RateAndTimestamp(Contract memory _contract)
        external
        view
        returns (
            uint256 _collateralExchangeRate,
            uint256 _loanExchangeRate,
            uint256 _repaymemtExchangeRate,
            uint256 _rateUpdateTime
        )
    {
        int256 priceCollateral;
        int256 priceLoan;
        int256 priceRepayment;

        if (_contract.terms.collateralAsset == address(0)) {
            (priceCollateral, _rateUpdateTime) = RateBNBwithUSDAttimestamp();
        } else {
            (priceCollateral, _rateUpdateTime) = getRateAndTimestamp(
                _contract.terms.collateralAsset
            );
        }
        _collateralExchangeRate = uint256(priceCollateral) * 10**10;

        if (_contract.terms.loanAsset == address(0)) {
            (priceLoan, _rateUpdateTime) = RateBNBwithUSDAttimestamp();
        } else {
            (priceLoan, _rateUpdateTime) = getRateAndTimestamp(
                _contract.terms.loanAsset
            );
        }
        _loanExchangeRate = uint256(priceLoan) * 10**10;

        if (_contract.terms.repaymentAsset == address(0)) {
            (priceRepayment, _rateUpdateTime) = RateBNBwithUSDAttimestamp();
        } else {
            (priceRepayment, _rateUpdateTime) = getRateAndTimestamp(
                _contract.terms.repaymentAsset
            );
        }
        _repaymemtExchangeRate = uint256(priceRepayment) * 10**10;
    }

    // ======================================= NFT==========================

    // tinh tien lai: interest = loanAmount * interestByLoanDurationType (interestByLoanDurationType = % lãi * số kì * loại kì / (365*100))
    function calculateInterestNFT(IPawnNFT.Contract memory _contract)
        external
        view
        returns (uint256 interest)
    {
        uint256 interestToUSD;
        uint256 repaymentAssetToUSD;
        uint256 _interestByLoanDurationType;

        if (
            _contract.terms.repaymentCycleType == IPawnNFT.LoanDurationType.WEEK
        ) {
            _interestByLoanDurationType =
                (_contract.terms.interest * 7 * 10**5) /
                (100 * 365);
        } else {
            _interestByLoanDurationType =
                (_contract.terms.interest * 30 * 10**5) /
                (100 * 365);
        }

        if (_contract.terms.loanAsset == address(0)) {
            interestToUSD =
                (uint256(Exchange.RateBNBwithUSD())) *
                10**10 *
                _contract.terms.loanAmount;
        } else {
            interestToUSD =
                (
                    uint256(
                        Exchange.getLatesPriceToUSD(_contract.terms.loanAsset)
                    )
                ) *
                10**10 *
                _contract.terms.loanAmount;
        }

        if (_contract.terms.repaymentAsset == address(0)) {
            repaymentAssetToUSD = (uint256(Exchange.RateBNBwithUSD())) * 10**10;
        } else {
            repaymentAssetToUSD =
                (
                    uint256(
                        Exchange.getLatesPriceToUSD(
                            _contract.terms.repaymentAsset
                        )
                    )
                ) *
                10**10;
        }

        interest =
            (interestToUSD * _interestByLoanDurationType) /
            (repaymentAssetToUSD * 10**5);
    }

    function calculatePenaltyNFT(
        IPawnNFT.PaymentRequest memory _paymentrequest,
        IPawnNFT.Contract memory _contract,
        uint256 _penaltyRate
    ) external pure returns (uint256 valuePenalty) {
        uint256 _interestByLoanDurationType;
        if (
            _contract.terms.repaymentCycleType == IPawnNFT.LoanDurationType.WEEK
        ) {
            _interestByLoanDurationType =
                (_contract.terms.interest * 7 * 10**5) /
                (100 * 365);
        } else {
            _interestByLoanDurationType =
                (_contract.terms.interest * 30 * 10**5) /
                (100 * 365);
        }

        valuePenalty =
            (_paymentrequest.remainingPenalty *
                10**5 +
                _paymentrequest.remainingPenalty *
                _interestByLoanDurationType +
                _paymentrequest.remainingInterest *
                _penaltyRate) /
            10**5;
    }

    function RateAndTimestampNFT(
        IPawnNFT.Contract memory _contract,
        address _token
    )
        external
        view
        returns (
            uint256 _collateralExchangeRate,
            uint256 _loanExchangeRate,
            uint256 _repaymemtExchangeRate,
            uint256 _rateUpdateTime
        )
    {
        int256 priceCollateral;
        int256 priceLoan;
        int256 priceRepayment;

        if (_token == address(0)) {
            (priceCollateral, _rateUpdateTime) = RateBNBwithUSDAttimestamp();
        } else {
            (priceCollateral, _rateUpdateTime) = getRateAndTimestamp(_token);
        }
        _collateralExchangeRate = uint256(priceCollateral) * 10**10;

        if (_contract.terms.loanAsset == address(0)) {
            (priceLoan, _rateUpdateTime) = RateBNBwithUSDAttimestamp();
        } else {
            (priceLoan, _rateUpdateTime) = getRateAndTimestamp(
                _contract.terms.loanAsset
            );
        }
        _loanExchangeRate = uint256(priceLoan) * 10**10;

        if (_contract.terms.repaymentAsset == address(0)) {
            (priceRepayment, _rateUpdateTime) = RateBNBwithUSDAttimestamp();
        } else {
            (priceRepayment, _rateUpdateTime) = getRateAndTimestamp(
                _contract.terms.repaymentAsset
            );
        }
        _repaymemtExchangeRate = uint256(priceRepayment) * 10**10;
    }
}
