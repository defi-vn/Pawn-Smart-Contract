// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/** ==================================Collateral============================ */

// Enum
enum LoanDurationType_NFT {
    WEEK,
    MONTH
}
enum CollateralStatus_NFT {
    OPEN,
    DOING,
    COMPLETED,
    CANCEL
}
enum OfferStatus_NFT {
    PENDING,
    ACCEPTED,
    COMPLETED,
    CANCEL
}
enum ContractStatus_NFT {
    ACTIVE,
    COMPLETED,
    DEFAULT
}
enum PaymentRequestStatusEnum_NFT {
    ACTIVE,
    LATE,
    COMPLETE,
    DEFAULT
}
enum PaymentRequestTypeEnum_NFT {
    INTEREST,
    OVERDUE,
    LOAN
}
enum ContractLiquidedReasonType_NFT {
    LATE,
    RISK,
    UNPAID
}

struct Collateral_NFT {
    address owner;
    address nftContract;
    uint256 nftTokenId;
    uint256 loanAmount;
    address loanAsset;
    uint256 nftTokenQuantity;
    uint256 expectedDurationQty;
    LoanDurationType_NFT durationType;
    CollateralStatus_NFT status;
}

/** =========================================OFFER==================================== */

struct CollateralOfferList_NFT {
    //offerId => Offer
    mapping(uint256 => Offer_NFT) offerMapping;
    uint256[] offerIdList;
    bool isInit;
}

struct Offer_NFT {
    address owner;
    address repaymentAsset;
    uint256 loanToValue;
    uint256 loanAmount;
    uint256 interest;
    uint256 duration;
    OfferStatus_NFT status;
    LoanDurationType_NFT loanDurationType;
    LoanDurationType_NFT repaymentCycleType;
    uint256 liquidityThreshold;
}

/** ==========================================Contract==================================== */
struct ContractTerms_NFT {
    address borrower;
    address lender;
    uint256 nftTokenId;
    address nftCollateralAsset;
    uint256 nftCollateralAmount;
    address loanAsset;
    uint256 loanAmount;
    address repaymentAsset;
    uint256 interest;
    LoanDurationType_NFT repaymentCycleType;
    uint256 liquidityThreshold;
    uint256 contractStartDate;
    uint256 contractEndDate;
    uint256 lateThreshold;
    uint256 systemFeeRate;
    uint256 penaltyRate;
    uint256 prepaidFeeRate;
}

struct Contract_NFT {
    uint256 nftCollateralId;
    uint256 offerId;
    ContractTerms_NFT terms;
    ContractStatus_NFT status;
    uint8 lateCount;
}

/**====================================REPAYMENT======================= */
struct PaymentRequest_NFT {
    uint256 requestId;
    PaymentRequestTypeEnum_NFT paymentRequestType;
    uint256 remainingLoan;
    uint256 penalty;
    uint256 interest;
    uint256 remainingPenalty;
    uint256 remainingInterest;
    uint256 dueDateTimestamp;
    bool chargePrepaidFee;
    PaymentRequestStatusEnum_NFT status;
}

struct ContractRawData_NFT {
    uint256 _nftCollateralId;
    Collateral_NFT _collateral;
    uint256 _offerId;
    uint256 _loanAmount;
    address _lender;
    address _repaymentAsset;
    uint256 _interest;
    LoanDurationType_NFT _repaymentCycleType;
    uint256 _liquidityThreshold;
    uint256 exchangeRate;
}

struct ContractLiquidationData_NFT {
    uint256 contractId;
    uint256 tokenEvaluationExchangeRate;
    uint256 loanExchangeRate;
    uint256 repaymentExchangeRate;
    uint256 rateUpdateTime;
    ContractLiquidedReasonType_NFT reasonType;
}

struct RepaymentEventData_NFT {
    uint256 contractId;
    uint256 paidPenaltyAmount;
    uint256 paidInterestAmount;
    uint256 paidLoanAmount;
    uint256 paidPenaltyFeeAmount;
    uint256 paidInterestFeeAmount;
    uint256 prepaidAmount;
    uint256 requestId;
    uint256 UID;
}

library PawnNFTLib {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /**
     * @dev safe transfer BNB or ERC20
     * @param  asset is address of the cryptocurrency to be transferred
     * @param  from is the address of the transferor
     * @param  to is the address of the receiver
     * @param  amount is transfer amount
     */
    function safeTransfer(
        address asset,
        address from,
        address to,
        uint256 amount
    ) internal {
        if (asset == address(0)) {
            require(from.balance >= amount, "not-enough-balance");
            // Handle BNB
            if (to == address(this)) {
                // Send to this contract
            } else if (from == address(this)) {
                // Send from this contract
                (bool success, ) = to.call{value: amount}("");
                require(success, "fail-transfer-bnb");
            } else {
                // Send from other address to another address
                require(false, "not-allow-transfer");
            }
        } else {
            // Handle ERC20
            uint256 prebalance = IERC20Upgradeable(asset).balanceOf(to);
            require(
                IERC20Upgradeable(asset).balanceOf(from) >= amount,
                "not-enough-balance"
            );
            if (from == address(this)) {
                // transfer direct to to
                IERC20Upgradeable(asset).safeTransfer(to, amount);
            } else {
                require(
                    IERC20Upgradeable(asset).allowance(from, address(this)) >=
                        amount,
                    "not-enough-allowance"
                );
                IERC20Upgradeable(asset).safeTransferFrom(from, to, amount);
            }
            require(
                IERC20Upgradeable(asset).balanceOf(to) - amount == prebalance,
                "not-transfer-enough"
            );
        }
    }

    function safeTranferNFTToken(
        address _nftToken,
        address _from,
        address _to,
        uint256 _id,
        uint256 _amount
    ) internal {
        // check address token
        require(
            _nftToken != address(0),
            "Address token must be different address(0)."
        );

        // check address from
        require(
            _from != address(0),
            "Address from must be different address(0)."
        );

        // check address from
        require(_to != address(0), "Address to must be different address(0).");

        // Check amount token
        //        require(_amount > 0, "Amount must be grean than 0.");

        // Check balance of from,
        require(
            IERC721(_nftToken).balanceOf(_from) >= _amount,
            "Your balance not enough."
        );

        // Transfer token
        IERC721(_nftToken).safeTransferFrom(_from, _to, _id, "");
    }

    /**
     * @dev Calculate the duration of the contract
     * @param  durationType is loan duration type of contract (WEEK/MONTH)
     * @param  duration is duration of contract
     */
    function calculateContractDuration(
        LoanDurationType_NFT durationType,
        uint256 duration
    ) internal pure returns (uint256 inSeconds) {
        if (durationType == LoanDurationType_NFT.WEEK) {
            // inSeconds = 7 * 24 * 3600 * duration;
            inSeconds = 600 * duration; //test
        } else {
            // inSeconds = 30 * 24 * 3600 * duration;
            inSeconds = 900 * duration; // test
        }
    }

    function isPrepaidChargeRequired(
        LoanDurationType_NFT durationType,
        uint256 startDate,
        uint256 endDate
    ) internal pure returns (bool) {
        uint256 week = 600;
        uint256 month = 900;

        if (durationType == LoanDurationType_NFT.WEEK) {
            // if loan contract only lasts one week
            if ((endDate - startDate) <= week) {
                return false;
            } else {
                return true;
            }
        } else {
            // if loan contract only lasts one month
            if ((endDate - startDate) <= month) {
                return false;
            } else {
                return true;
            }
        }
    }

    function calculatedueDateTimestampInterest(
        LoanDurationType_NFT durationType
    ) internal pure returns (uint256 duedateTimestampInterest) {
        if (durationType == LoanDurationType_NFT.WEEK) {
            duedateTimestampInterest = 180;
        } else {
            duedateTimestampInterest = 300;
        }
    }

    function calculatedueDateTimestampPenalty(LoanDurationType_NFT durationType)
        internal
        pure
        returns (uint256 duedateTimestampInterest)
    {
        if (durationType == LoanDurationType_NFT.WEEK) {
            duedateTimestampInterest = 600 - 180;
        } else {
            duedateTimestampInterest = 900 - 300;
        }
    }

    /**
     * @dev Calculate balance of wallet address
     * @param  _token is address of token
     * @param  from is address wallet
     */
    function calculateAmount(address _token, address from)
        internal
        view
        returns (uint256 _amount)
    {
        if (_token == address(0)) {
            // BNB
            _amount = from.balance;
        } else {
            // ERC20
            _amount = IERC20Upgradeable(_token).balanceOf(from);
        }
    }

    /**
     * @dev Calculate fee of system
     * @param  amount amount charged to the system
     * @param  feeRate is system fee rate
     */
    function calculateSystemFee(
        uint256 amount,
        uint256 feeRate,
        uint256 zoom
    ) internal pure returns (uint256 feeAmount) {
        feeAmount = (amount * feeRate) / (zoom * 100);
    }
}

library CollateralLib_NFT {
    function create(
        Collateral_NFT storage self,
        address _nftContract,
        uint256 _nftTokenId,
        uint256 _loanAmount,
        address _loanAsset,
        uint256 _nftTokenQuantity,
        uint256 _expectedDurationQty,
        LoanDurationType_NFT _durationType
    ) internal {
        self.owner = msg.sender;
        self.nftContract = _nftContract;
        self.nftTokenId = _nftTokenId;
        self.loanAmount = _loanAmount;
        self.loanAsset = _loanAsset;
        self.nftTokenQuantity = _nftTokenQuantity;
        self.expectedDurationQty = _expectedDurationQty;
        self.durationType = _durationType;
        self.status = CollateralStatus_NFT.OPEN;
    }
}

library OfferLib_NFT {
    function create(
        Offer_NFT storage self,
        address _repaymentAsset,
        uint256 _loanToValue,
        uint256 _loanAmount,
        uint256 _interest,
        uint256 _duration,
        uint256 _liquidityThreshold,
        LoanDurationType_NFT _loanDurationType,
        LoanDurationType_NFT _repaymentCycleType
    ) internal {
        self.owner = msg.sender;
        self.repaymentAsset = _repaymentAsset;
        self.loanToValue = _loanToValue;
        self.loanAmount = _loanAmount;
        self.interest = _interest;
        self.duration = _duration;
        self.status = OfferStatus_NFT.PENDING;
        self.loanDurationType = LoanDurationType_NFT(_loanDurationType);
        self.repaymentCycleType = LoanDurationType_NFT(_repaymentCycleType);
        self.liquidityThreshold = _liquidityThreshold;
    }

    function cancel(
        Offer_NFT storage self,
        uint256 _id,
        address _collateralOwner,
        CollateralOfferList_NFT storage _collateralOfferList
    ) internal {
        require(_collateralOfferList.isInit == true, "1"); // offer-col
        require(
            self.owner == msg.sender || _collateralOwner == msg.sender,
            "2"
        ); // owner
        require(self.status == OfferStatus_NFT.PENDING, "3"); // offer

        delete _collateralOfferList.offerMapping[_id];
        for (uint256 i = 0; i < _collateralOfferList.offerIdList.length; i++) {
            if (_collateralOfferList.offerIdList[i] == _id) {
                _collateralOfferList.offerIdList[i] = _collateralOfferList
                    .offerIdList[_collateralOfferList.offerIdList.length - 1];
                break;
            }
        }
        delete _collateralOfferList.offerIdList[
            _collateralOfferList.offerIdList.length - 1
        ];
    }
}
