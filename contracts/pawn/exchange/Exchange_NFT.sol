// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import "../pawn-nft-v2/PawnNFTLib.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

contract Exchange_NFT is
    Initializable,
    UUPSUpgradeable,
    AccessControlUpgradeable
{
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

    // exchangeRate offer
    function exchangeRateOfOffer(address _adLoanAsset, address _adRepayment)
        external
        view
        returns (uint256 exchangeRate)
    {
        // exchangeRate = loan / repayment
        if (_adLoanAsset == address(0)) {
            // if LoanAsset is address(0) , check BNB exchange rate with BNB
            (, uint256 exRate) = SafeMathUpgradeable.tryDiv(
                RateBNBwithUSD() * 10**18,
                getLatesPriceToUSD(_adRepayment)
            );
            exchangeRate = exRate;
        } else {
            // all LoanAsset and repaymentAsset are crypto or token is different BNB
            (, uint256 exRate) = SafeMathUpgradeable.tryDiv(
                (getLatesPriceToUSD(_adLoanAsset) * 10**18),
                getLatesPriceToUSD(_adRepayment)
            );
            exchangeRate = exRate;
        }
    }

    function calculateInterest(
        uint256 _remainingLoan,
        Contract_NFT memory _contract
    ) external view returns (uint256 interest) {
        uint256 _interestToUSD;
        uint256 _repaymentAssetToUSD;
        uint256 _interestByLoanDurationType;

        // tinh tien lai
        if (_contract.terms.loanAsset == address(0)) {
            // if loanAsset is BNB
            (, uint256 interestToAmount) = SafeMathUpgradeable.tryMul(
                _contract.terms.interest,
                _remainingLoan
            );
            (, uint256 interestRate) = SafeMathUpgradeable.tryMul(
                interestToAmount,
                RateBNBwithUSD()
            );
        }
    }
}
