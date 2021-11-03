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

    function getLatestRoundData(AggregatorV3Interface getPriceToUSD)
        internal
        view
        returns (uint256, uint256)
    {
        (, int256 _price, , uint256 _timeStamp, ) = getPriceToUSD
            .latestRoundData();

        require(_price > 0, "Negative or zero rate");

        return (uint256(_price), _timeStamp);
    }

    // lay gia cua dong BNB
    function RateBNBwithUSD() internal view returns (uint256 price) {
        AggregatorV3Interface getPriceToUSD = AggregatorV3Interface(
            0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526
        );

        (price, ) = getLatestRoundData(getPriceToUSD);
    }

    // lay ti gia dong BNB + timestamp
    function RateBNBwithUSDAttimestamp()
        internal
        view
        returns (uint256 price, uint256 timeStamp)
    {
        AggregatorV3Interface getPriceToUSD = AggregatorV3Interface(
            0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526
        );

        (price, timeStamp) = getLatestRoundData(getPriceToUSD);
    }

    // lay gia cua cac crypto va token khac da duoc them vao ListcryptoExchange
    function getLatesPriceToUSD(address _adcrypto)
        internal
        view
        returns (uint256 price)
    {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            ListCryptoExchange[_adcrypto]
        );

        (price, ) = getLatestRoundData(priceFeed);
    }

    // lay ti gia va timestamp cua cac crypto va token da duoc them vao ListcryptoExchange
    function getRateAndTimestamp(address _adcrypto)
        internal
        view
        returns (uint256 price, uint256 timeStamp)
    {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            ListCryptoExchange[_adcrypto]
        );

        (price, timeStamp) = getLatestRoundData(priceFeed);
    }

    function calculateLoanAmountAndExchangeRate(
        Collateral memory _col,
        PawnShopPackage memory _pkg
    ) external view returns (uint256 loanAmount, uint256 exchangeRate) {
        (loanAmount, exchangeRate, , , ) = calcLoanAmountAndExchangeRate(
            _col.collateralAddress,
            _col.amount,
            _col.loanAsset,
            _pkg.loanToValue,
            _pkg.repaymentAsset
        );
    }

    function calcLoanAmountAndExchangeRate(
        address collateralAddress,
        uint256 amount,
        address loanAsset,
        uint256 loanToValue,
        address repaymentAsset
    )
        public
        view
        returns (
            uint256 loanAmount,
            uint256 exchangeRate,
            uint256 collateralToUSD,
            uint256 rateLoanAsset,
            uint256 rateRepaymentAsset
        )
    {
        if (collateralAddress == address(0)) {
            // If collateral address is address(0), check BNB exchange rate with USD
            // collateralToUSD = (uint256(RateBNBwithUSD()) * loanToValue * amount) / (100 * 10**5);
            (, uint256 ltvAmount) = SafeMathUpgradeable.tryMul(
                loanToValue,
                amount
            );
            (, uint256 collRate) = SafeMathUpgradeable.tryMul(
                ltvAmount,
                uint256(RateBNBwithUSD())
            );
            (, uint256 collToUSD) = SafeMathUpgradeable.tryDiv(
                collRate,
                (100 * 10**5)
            );

            collateralToUSD = collToUSD;
        } else {
            // If collateral address is not BNB, get latest price in USD of collateral crypto
            // collateralToUSD = (uint256(getLatesPriceToUSD(collateralAddress))  * loanToValue * amount) / (100 * 10**5);
            (, uint256 ltvAmount) = SafeMathUpgradeable.tryMul(
                loanToValue,
                amount
            );
            (, uint256 collRate) = SafeMathUpgradeable.tryMul(
                ltvAmount,
                getLatesPriceToUSD(collateralAddress)
            );
            (, uint256 collToUSD) = SafeMathUpgradeable.tryDiv(
                collRate,
                (100 * 10**5)
            );

            collateralToUSD = collToUSD;
        }

        if (loanAsset == address(0)) {
            // get price of BNB in USD
            rateLoanAsset = RateBNBwithUSD();
        } else {
            // get price in USD of crypto as loan asset
            rateLoanAsset = getLatesPriceToUSD(loanAsset);
        }

        (, uint256 lAmount) = SafeMathUpgradeable.tryDiv(
            collateralToUSD,
            rateLoanAsset
        );
        // loanAmount = collateralToUSD / rateLoanAsset;
        uint256 tempLoamAmount = lAmount / 10**13;
        loanAmount = tempLoamAmount * 10**13;

        if (repaymentAsset == address(0)) {
            // get price in USD of BNB as repayment asset
            rateRepaymentAsset = RateBNBwithUSD();
        } else {
            // get latest price in USD of crypto as repayment asset
            rateRepaymentAsset = getLatesPriceToUSD(repaymentAsset);
        }

        // calculate exchange rate
        (, uint256 xchange) = SafeMathUpgradeable.tryDiv(
            rateLoanAsset * 10**5,
            rateRepaymentAsset
        );
        exchangeRate = xchange * 10**13;
    }

    // calculate Rate of LoanAsset with repaymentAsset
    function exchangeRateofOffer(address _adLoanAsset, address _adRepayment)
        external
        view
        returns (uint256 exchangeRateOfOffer)
    {
        //  exchangeRateOffer = loanAsset / repaymentAsset
        if (_adLoanAsset == address(0)) {
            // if LoanAsset is address(0) , check BNB exchange rate with BNB
            (, uint256 exRate) = SafeMathUpgradeable.tryDiv(
                RateBNBwithUSD(),
                getLatesPriceToUSD(_adRepayment)
            );
            exchangeRateOfOffer = exRate;
        } else {
            // all LoanAsset and repaymentAsset are crypto or token is different BNB
            (, uint256 exRate) = SafeMathUpgradeable.tryDiv(
                (getLatesPriceToUSD(_adLoanAsset) * 10**5),
                getLatesPriceToUSD(_adRepayment)
            );
            exchangeRateOfOffer = exRate;
        }
    }

    //===========================================Tinh interest =======================================
    // tinh tien lai cua moi ky: interest = loanAmount * interestByLoanDurationType
    //(interestByLoanDurationType = % lãi * số kì * loại kì / (365*100))

    function calculateInterest(
        uint256 _remainingLoan,
        Contract memory _contract
    ) external view returns (uint256 interest) {
        uint256 _interestToUSD;
        uint256 _repaymentAssetToUSD;
        uint256 _interestByLoanDurationType;

        // tien lai
        if (_contract.terms.loanAsset == address(0)) {
            // neu loanAsset la dong BNB
            // interestToUSD = (uint256(RateBNBwithUSD()) *_contract.terms.loanAmount) * _contract.terms.interest;
            (, uint256 interestToAmount) = SafeMathUpgradeable.tryMul(
                _contract.terms.interest,
                _remainingLoan
            );
            (, uint256 interestRate) = SafeMathUpgradeable.tryMul(
                interestToAmount,
                RateBNBwithUSD()
            );
            (, uint256 itrestRate) = SafeMathUpgradeable.tryDiv(
                interestRate,
                (100 * 10**5)
            );
            _interestToUSD = itrestRate;
        } else {
            // Neu loanAsset la cac dong crypto va token khac BNB
            // interestToUSD = (uint256(getLatesPriceToUSD(_contract.terms.loanAsset)) * _contract.terms.loanAmount) * _contractterms.interest;
            (, uint256 interestToAmount) = SafeMathUpgradeable.tryMul(
                _contract.terms.interest,
                _remainingLoan
            );
            (, uint256 interestRate) = SafeMathUpgradeable.tryMul(
                interestToAmount,
                getLatesPriceToUSD(_contract.terms.loanAsset)
            );
            (, uint256 itrestRate) = SafeMathUpgradeable.tryDiv(
                interestRate,
                (100 * 10**5)
            );
            _interestToUSD = itrestRate;
        }

        // tinh tien lai cho moi ky thanh toan
        if (_contract.terms.repaymentCycleType == LoanDurationType.WEEK) {
            // neu thoi gian vay theo tuan thì L = loanAmount * interest * 7 /365
            (, uint256 _interest) = SafeMathUpgradeable.tryDiv(
                (_interestToUSD * 7),
                365
            );
            _interestByLoanDurationType = _interest;
        } else {
            // thoi gian vay theo thang thi  L = loanAmount * interest * 30 /365
            //  _interestByLoanDurationType =(_contract.terms.interest * 30) / 365);
            (, uint256 _interest) = SafeMathUpgradeable.tryDiv(
                (_interestToUSD * 30),
                365
            );
            _interestByLoanDurationType = _interest;
        }

        // tinh Rate cua dong repayment
        if (_contract.terms.repaymentAsset == address(0)) {
            // neu dong tra la BNB
            _repaymentAssetToUSD = RateBNBwithUSD();
        } else {
            // neu dong tra kha BNB
            _repaymentAssetToUSD = getLatesPriceToUSD(
                _contract.terms.repaymentAsset
            );
        }

        // tien lai theo moi kỳ tinh ra dong tra
        (, uint256 saInterest) = SafeMathUpgradeable.tryDiv(
            _interestByLoanDurationType,
            _repaymentAssetToUSD
        );
        // uint256 tempInterest = saInterest / 10**13;
        // interest = tempInterest * 10**13;
        interest = DivRound(saInterest);
    }

    //=============================== Tinh penalty =====================================

    //  p = (p(n-1)) + (p(n-1) *(L)) + (L(n-1)*(p))

    function calculatePenalty(
        PaymentRequest memory _paymentrequest,
        Contract memory _contract,
        uint256 _penaltyRate
    ) external pure returns (uint256 valuePenalty) {
        uint256 _interestOfPenalty;
        if (_contract.terms.repaymentCycleType == LoanDurationType.WEEK) {
            // neu ky vay theo tuan thi (L) = interest * 7 /365
            //_interestByLoanDurationType =(_contract.terms.interest * 7) / (100 * 365);
            (, uint256 saInterestByLoanDurationType) = SafeMathUpgradeable
                .tryDiv((_contract.terms.interest * 7), 365);
            (, uint256 saPenaltyOfInterestRate) = SafeMathUpgradeable.tryMul(
                _paymentrequest.remainingPenalty,
                saInterestByLoanDurationType
            );
            (, uint256 saPenaltyOfInterest) = SafeMathUpgradeable.tryDiv(
                saPenaltyOfInterestRate,
                (100 * 10**5)
            );
            _interestOfPenalty = saPenaltyOfInterest;
        } else {
            // _interestByLoanDurationType =(_contract.terms.interest * 30) /(100 * 365);
            (, uint256 saInterestByLoanDurationType) = SafeMathUpgradeable
                .tryDiv(_contract.terms.interest * 30, 365);
            (, uint256 saPenaltyOfInterestRate) = SafeMathUpgradeable.tryMul(
                _paymentrequest.remainingPenalty,
                saInterestByLoanDurationType
            );
            (, uint256 saPenaltyOfInterest) = SafeMathUpgradeable.tryDiv(
                saPenaltyOfInterestRate,
                (100 * 10**5)
            );
            _interestOfPenalty = saPenaltyOfInterest;
        }
        // valuePenalty =(_paymentrequest.remainingPenalty +_paymentrequest.remainingPenalty *_interestByLoanDurationType +_paymentrequest.remainingInterest *_penaltyRate);
        //  uint256 penalty = _paymentrequest.remainingInterest * _penaltyRate;
        (, uint256 penalty) = SafeMathUpgradeable.tryDiv(
            (_paymentrequest.remainingInterest * _penaltyRate),
            (100 * 10**5)
        );
        uint256 _penalty = _paymentrequest.remainingPenalty +
            _interestOfPenalty +
            penalty;
        // uint256 tempPenalty = _penalty / 10**13;
        // valuePenalty = tempPenalty * 10**13;
        valuePenalty = DivRound(_penalty);
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
        // Get exchange rate of collateral token
        if (_contract.terms.collateralAsset == address(0)) {
            (
                _collateralExchangeRate,
                _rateUpdateTime
            ) = RateBNBwithUSDAttimestamp();
        } else {
            (_collateralExchangeRate, _rateUpdateTime) = getRateAndTimestamp(
                _contract.terms.collateralAsset
            );
        }

        // Get exchange rate of loan token
        if (_contract.terms.loanAsset == address(0)) {
            (_loanExchangeRate, _rateUpdateTime) = RateBNBwithUSDAttimestamp();
        } else {
            (_loanExchangeRate, _rateUpdateTime) = getRateAndTimestamp(
                _contract.terms.loanAsset
            );
        }

        // Get exchange rate of repayment token
        if (_contract.terms.repaymentAsset == address(0)) {
            (
                _repaymemtExchangeRate,
                _rateUpdateTime
            ) = RateBNBwithUSDAttimestamp();
        } else {
            (_repaymemtExchangeRate, _rateUpdateTime) = getRateAndTimestamp(
                _contract.terms.repaymentAsset
            );
        }
    }

    // tinh ti gia cua repayment / collateralAsset  va   loanAsset / collateralAsset
    function collateralPerRepaymentAndLoanTokenExchangeRate(
        Contract memory _contract
    )
        external
        view
        returns (
            uint256 _collateralPerRepaymentTokenExchangeRate,
            uint256 _collateralPerLoanAssetExchangeRate
        )
    {
        uint256 priceRepaymentAset;
        uint256 priceLoanAsset;
        uint256 priceCollateralAsset;

        if (_contract.terms.repaymentAsset == address(0)) {
            // neu repaymentAsset la BNB
            priceRepaymentAset = RateBNBwithUSD();
        } else {
            // neu la cac dong khac
            priceRepaymentAset = getLatesPriceToUSD(
                _contract.terms.repaymentAsset
            );
        }

        if (_contract.terms.loanAsset == address(0)) {
            // neu dong loan asset la BNB
            priceLoanAsset = RateBNBwithUSD();
        } else {
            // cac dong khac
            priceLoanAsset = getLatesPriceToUSD(_contract.terms.loanAsset);
        }

        if (_contract.terms.collateralAsset == address(0)) {
            // neu collateralAsset la bnb
            priceCollateralAsset = RateBNBwithUSD();
        } else {
            // la cac dong khac
            priceCollateralAsset = getLatesPriceToUSD(
                _contract.terms.collateralAsset
            );
        }

        bool success;
        // tempCollateralPerRepaymentTokenExchangeRate = priceRepaymentAsset / priceCollateralAsset
        (
            success,
            _collateralPerRepaymentTokenExchangeRate
        ) = SafeMathUpgradeable.tryDiv(
            (priceRepaymentAset * 10**10),
            priceCollateralAsset
        );
        require(success, "Safe math: division by zero");

        // _collateralPerRepaymentTokenExchangeRate = tempCollateralPerRepaymentTokenExchangeRate;

        // tempCollateralPerLoanAssetExchangeRate = priceLoanAsset / priceCollateralAsset
        (success, _collateralPerLoanAssetExchangeRate) = SafeMathUpgradeable
            .tryDiv((priceLoanAsset * 10**10), priceCollateralAsset);

        require(success, "Safe math: division by zero");

        // _collateralPerLoanAssetExchangeRate = tempCollateralPerLoanAssetExchangeRate;
    }

    function DivRound(uint256 a) private pure returns (uint256) {
        // kiem tra so du khi chia 10**13. Neu lon hon 5 *10**12 khi chia xong thi lam tron len(+1) roi nhan lai voi 10**13
        //con nho hon thi giu nguyen va nhan lai voi 10**13

        uint256 tmp = a % 10**13;
        uint256 tm;
        if (tmp < 5 * 10**12) {
            tm = a / 10**13;
        } else {
            tm = a / 10**13 + 1;
        }
        uint256 rouding = tm * 10**13;
        return rouding;
    }
}
