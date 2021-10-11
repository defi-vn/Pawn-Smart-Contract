// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import "../pawn-p2p/PawnLib.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";

contract Exchange is AccessControlUpgradeable{
    using AddressUpgradeable for address;
   

    function __DFYAccessControl_init() internal initializer {
        __AccessControl_init();

        __DFYAccessControl_init_unchained();
    }

    function __DFYAccessControl_init_unchained() internal initializer {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    event ContractAdminChanged(address from, address to);

    /**
    * @dev change contract's admin to a new address
    */
    function changeContractAdmin(address newAdmin) public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        // Check if the new Admin address is a contract address
        require(!newAdmin.isContract(), "New admin must not be a contract");
        
        grantRole(DEFAULT_ADMIN_ROLE, newAdmin);
        renounceRole(DEFAULT_ADMIN_ROLE, _msgSender());

        emit ContractAdminChanged(_msgSender(), newAdmin);
    }

    constructor(){}
    mapping(address => address) public ListcryptoExchange;

    // set dia chi cac token ( crypto) tuong ung voi dia chi chuyen doi ra USD tren chain link
    function setCryptoExchange (
        address _cryptoAddress, 
        address _latestPriceAddress
    ) 
    public onlyRole(DEFAULT_ADMIN_ROLE)
    {
        ListcryptoExchange[_cryptoAddress] = _latestPriceAddress;
    }

    // lay gia cua dong BNB
    function RateBNBwithUSD ()
    internal view 
    returns(int)
    {
        AggregatorV3Interface getPriceToUSD = AggregatorV3Interface(0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526);
        (
            ,
            int price,
            ,
            ,
        ) = getPriceToUSD.latestRoundData();
        return price;
    }
    // lay ti gia dong BNB + timestamp
    function RateBNBwithUSDAttimestamp() 
    internal view 
    returns(int price, uint timeStamp)
    {
        AggregatorV3Interface getPriceToUSD = AggregatorV3Interface(0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526);
        (
            ,
            price,
            ,
            timeStamp,
        ) = getPriceToUSD.latestRoundData();
      
    }

    // lay gia cua cac crypto va token khac da duoc them vao ListcryptoExchange
    function getLatesPriceToUSD (
        address _adcrypto
    ) 
    internal view 
    returns(int)
    {
        AggregatorV3Interface  priceFeed = AggregatorV3Interface(ListcryptoExchange[_adcrypto]);
         (
            , 
            int price,
            ,
            ,
            
        ) = priceFeed.latestRoundData();
        return price;
    }


    // lay ti gia va timestamp cua cac crypto va token da duoc them vao ListcryptoExchange
    function getRateAndTimestamp (
        address _adcrypto
    ) 
    internal view 
    returns(int price, uint timeStamp) 
    {
        AggregatorV3Interface  priceFeed = AggregatorV3Interface(ListcryptoExchange[_adcrypto]);
         (
            , 
            price,
            ,
            timeStamp,
            
        ) = priceFeed.latestRoundData();
        
    }

    // loanAmount= (CollateralAsset * amount * loanToValue) / RateLoanAsset
    // exchangeRate = RateLoanAsset / RateRepaymentAsset  
    function calculateLoanAmountAndExchangeRate (
        Collateral memory _col,
        PawnShopPackage memory _pkg
    )
    external view 
    returns (uint256 loanAmount, uint256 exchangeRate)
    {
        uint256 collateralToUSD;
        uint256 RateLoanAsset;
        uint256 RateRepaymentAsset;
        if(_col.collateralAddress == address(0))
        {
            collateralToUSD = (uint256(RateBNBwithUSD()) * 10**10 * _pkg.loanToValue * _col.amount) / 100;
        } else {
            collateralToUSD = (uint256(getLatesPriceToUSD(_col.collateralAddress)) * 10**10 * _pkg.loanToValue * _col.amount) / 100;
        }

        if(_col.loanAsset == address(0))
        {
            RateLoanAsset = uint256(RateBNBwithUSD()) * 10**10;
        } else {
            RateLoanAsset = uint256(getLatesPriceToUSD(_col.loanAsset)) * 10**10;
        }

        loanAmount = collateralToUSD / RateLoanAsset;

        if(_pkg.repaymentAsset == address(0))
        {
            RateRepaymentAsset = uint256(RateBNBwithUSD()) * 10**10;
        } else {
            RateRepaymentAsset = uint256(getLatesPriceToUSD(_pkg.repaymentAsset)) * 10**10;
        }

        exchangeRate = (10**5 * RateLoanAsset) / RateRepaymentAsset;       
    }

    // tinh tien lai: interest = loanAmount * interestByLoanDurationType (interestByLoanDurationType = % lãi * số kì * loại kì / (365*100))
    function calculateInteres (
        Contract memory _contract
    )
    external view 
    returns (uint256 interest)
    {
        uint256 interestToUSD;
        uint256 repaymentAssetToUSD;
        uint256 _interestByLoanDurationType;
        if(_contract.terms.repaymentCycleType == LoanDurationType.WEEK)
        {   
            _interestByLoanDurationType = (_contract.terms.interest * 7 * 10**5) / (100*365);
        } else {  
            _interestByLoanDurationType = (_contract.terms.interest * 30 * 10**5) / (100*365);
        }

        if(_contract.terms.loanAsset == address(0))
        {
            interestToUSD = (uint256(RateBNBwithUSD()) * 10**10 *  _contract.terms.loanAmount);
        } else {
            interestToUSD = (uint256(getLatesPriceToUSD(_contract.terms.loanAsset)) * 10**10 * _contract.terms.loanAmount);
        }

        if(_contract.terms.repaymentAsset == address(0))
        {
            repaymentAssetToUSD = uint256(RateBNBwithUSD()) * 10**10;
        } else {
            repaymentAssetToUSD = uint256(getLatesPriceToUSD(_contract.terms.loanAsset));
        }

        interest = (interestToUSD * _interestByLoanDurationType) / (repaymentAssetToUSD * 10**5);

    }

    // tinh penalty 
    function calculatePenalty (
        PaymentRequest memory _paymentrequest,
        Contract memory _contract, 
        uint256 _penaltyRate
    )
    external view
    returns (uint256 valuePenalty)
    {
        uint256 _interestByLoanDurationType;
        if(_contract.terms.repaymentCycleType == LoanDurationType.WEEK)
        {   
            _interestByLoanDurationType = (_contract.terms.interest * 7 * 10**5) / (100*365);
        } else {  
            _interestByLoanDurationType = (_contract.terms.interest * 30 * 10**5) / (100*365);
        }

        valuePenalty = (_paymentrequest.remainingPenalty * 10**5 + _paymentrequest.remainingPenalty * _interestByLoanDurationType + _paymentrequest.remainingInterest * _penaltyRate) / 10**5;
    }

    // lay Rate va thoi gian cap nhat ti gia do
    function RateAndTimestamp (
        Contract memory _contract
    )
    external view 
    returns (uint256 _collateralExchangeRate, uint256 _loanExchangeRate, uint256 _repaymemtExchangeRate, uint256 _rateUpdateTime)
    {
        int priceCollateral;
        int priceLoan;
        int priceRepayment;

        if(_contract.terms.collateralAsset == address(0))
        {
            (priceCollateral,_rateUpdateTime) = RateBNBwithUSDAttimestamp();
        } else {
            (priceCollateral,_rateUpdateTime) = getRateAndTimestamp(_contract.terms.collateralAsset);
        }
        _collateralExchangeRate = uint256(priceCollateral) * 10 ** 10;

        if(_contract.terms.loanAsset == address(0))
        {
            (priceLoan,_rateUpdateTime) = RateBNBwithUSDAttimestamp();
        } else {
            (priceLoan,_rateUpdateTime) = getRateAndTimestamp(_contract.terms.loanAsset);
        }
        _loanExchangeRate = uint256(priceLoan) * 10 ** 10;

        if(_contract.terms.repaymentAsset == address(0))
        {
            (priceRepayment,_rateUpdateTime) = RateBNBwithUSDAttimestamp();
        } else {
            (priceRepayment,_rateUpdateTime) = getRateAndTimestamp(_contract.terms.repaymentAsset);
        }
        _repaymemtExchangeRate = uint256(priceRepayment) * 10**10;
    }



    









}

