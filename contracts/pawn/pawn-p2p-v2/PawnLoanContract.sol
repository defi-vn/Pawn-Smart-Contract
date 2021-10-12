// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./PawnModel.sol";
import "../access/DFY-AccessControl.sol";
import "../reputation/IReputation.sol";

contract PawnLoanContract is PawnModel
{
    using CountersUpgradeable for CountersUpgradeable.Counter;
    using AddressUpgradeable for address;
    using SafeMathUpgradeable for uint;

    mapping(address => bool) whitelistedPawnContract;

    /** ==================== Loan contract & Payment related state variables ==================== */
    uint256 public numberContracts;
    mapping(uint256 => Contract) public contracts;

    mapping(uint256 => PaymentRequest[]) public contractPaymentRequestMapping;

    mapping(uint256 => CollateralAsLoanRequestListStruct) public collateralAsLoanRequestMapping; // Map from collateral to loan request

    /** ==================== Loan contract related events ==================== */
    event LoanContractCreatedEvent(
        uint256 exchangeRate,
        address fromAddress,
        uint256 contractId,
        Contract data
    );

    event PaymentRequestEvent (
        int256 paymentRequestId,
        uint256 contractId,
        PaymentRequest data
    );

    event RepaymentEvent(
        uint256 contractId,
        uint256 paidPenaltyAmount,
        uint256 paidInterestAmount,
        uint256 paidLoanAmount,
        uint256 paidPenaltyFeeAmount,
        uint256 paidInterestFeeAmount,
        uint256 prepaidAmount,
        uint256 paymentRequestId
    );

    /** ==================== Liquidate & Default related events ==================== */
    event ContractLiquidedEvent(
        uint256 contractId,
        uint256 liquidedAmount,
        uint256 feeAmount,
        ContractLiquidedReasonType reasonType
    );

    event LoanContractCompletedEvent(uint256 contractId);

    /** ==================== Initialization ==================== */

    /**
    * @dev initialize function
    * @param _zoom is coefficient used to represent risk params
    */
    function initialize(uint32 _zoom) public initializer {
        __PawnModel_init(_zoom);
    }

    /** ================================ 2. ACCEPT COLLATERAL (FOR PAWNSHOP PACKAGE WORKFLOWS) ============================= */
    
    // /**
    // * @dev Create loan contract based on collateral & package info
    // * @param _collateralId is the ID of collateral
    // * @param _collateral is a copy of the collateral in memory
    // * @param _packageId is the ID of pawnshop package, can be lesser than 0
    // * @param _offerId is the ID of the offer, can be lesser than 0
    // * @param _loanAmount is the amount of crypto token being loaned
    // * @param _exchangeRate is the calculated exchange rate using Chainlink service
    // * @param _lender is the address of lender
    // * @param _repaymentAsset is the address of repayment token
    // * @param _interest is the interest rate of pawn package
    // * @param _repaymentCycleType is the cycle of payment, in weeks or months
    // * @param _liquidityThreshold is the threshold at which the contract will be liquidated
    // * @param _loanDurationQty is the duration the loan contract
    // */
    // function createContract(
    //     uint256 _collateralId,
    //     Collateral memory _collateral,
    //     int256 _packageId,
    //     int256 _offerId,
    //     uint256 _exchangeRate,
    //     uint256 _loanAmount,
    //     address _lender,
    //     address _repaymentAsset,
    //     uint256 _interest,
    //     LoanDurationType _repaymentCycleType,
    //     uint256 _liquidityThreshold,
    //     uint256 _loanDurationQty
    // ) 
    //     external
    //     onlyRole(OPERATOR_ROLE) 
    //     returns (uint256 _idx) 
    // {
    //     _idx = numberContracts;
    //     Contract storage newContract = contracts[_idx];
        
    //     newContract.collateralId = _collateralId;
    //     newContract.offerId = _offerId;
    //     newContract.pawnShopPackageId = int256(_packageId);
    //     newContract.status = ContractStatus.ACTIVE;
    //     newContract.lateCount = 0;
    //     newContract.terms.borrower = _collateral.owner;
    //     newContract.terms.lender = _lender;
    //     newContract.terms.collateralAsset = _collateral.collateralAddress;
    //     newContract.terms.collateralAmount = _collateral.amount;
    //     newContract.terms.loanAsset = _collateral.loanAsset;
    //     newContract.terms.loanAmount = _loanAmount;
    //     newContract.terms.repaymentCycleType = _repaymentCycleType;
    //     newContract.terms.repaymentAsset = _repaymentAsset;
    //     newContract.terms.interest = _interest;
    //     newContract.terms.liquidityThreshold = _liquidityThreshold;
    //     newContract.terms.contractStartDate = block.timestamp;
    //     newContract.terms.contractEndDate =
    //         block.timestamp +
    //         PawnLib.calculateContractDuration(
    //             _repaymentCycleType,
    //             _loanDurationQty
    //         );
    //     newContract.terms.lateThreshold = lateThreshold;
    //     newContract.terms.systemFeeRate = systemFeeRate;
    //     newContract.terms.penaltyRate = penaltyRate;
    //     newContract.terms.prepaidFeeRate = prepaidFeeRate;
    //     ++numberContracts;

    //     emit LoanContractCreatedEvent(_exchangeRate, msg.sender, _idx, newContract);
    // }

    function createContract(
        ContractRawData memory contractData
    ) 
        external
        onlyRole(OPERATOR_ROLE) 
        returns (uint256 _idx) 
    {
        _idx = numberContracts;
        Contract storage newContract = contracts[_idx];
        
        newContract.collateralId = contractData.collateralId;
        newContract.offerId = contractData.offerId;
        newContract.pawnShopPackageId = contractData.packageId;
        newContract.status = ContractStatus.ACTIVE;
        newContract.lateCount = 0;
        newContract.terms.borrower = contractData.borrower;
        newContract.terms.lender = contractData.lender;
        newContract.terms.collateralAsset = contractData.collateralAsset;
        newContract.terms.collateralAmount = contractData.collateralAmount;
        newContract.terms.loanAsset = contractData.loanAsset;
        newContract.terms.loanAmount = contractData.loanAmount;
        newContract.terms.repaymentCycleType = contractData.repaymentCycleType;
        newContract.terms.repaymentAsset = contractData.repaymentAsset;
        newContract.terms.interest = contractData.interest;
        newContract.terms.liquidityThreshold = contractData.liquidityThreshold;
        newContract.terms.contractStartDate = block.timestamp;
        newContract.terms.contractEndDate =
            block.timestamp +
            PawnLib.calculateContractDuration(
                contractData.repaymentCycleType,
                contractData.loanDurationQty
            );
        newContract.terms.lateThreshold = lateThreshold;
        newContract.terms.systemFeeRate = systemFeeRate;
        newContract.terms.penaltyRate = penaltyRate;
        newContract.terms.prepaidFeeRate = prepaidFeeRate;
        ++numberContracts;

        emit LoanContractCreatedEvent(contractData.exchangeRate, msg.sender, _idx, newContract);
    }

    function contractMustActive(uint256 _contractId)
        internal
        view
        returns (Contract storage _contract)
    {
        // Validate: Contract must active
        _contract = contracts[_contractId];
        require(_contract.status == ContractStatus.ACTIVE, '0'); // contr-act
    }

    /** ================================ 3. PAYMENT REQUEST & REPAYMENT WORKLOWS ============================= */

    function closePaymentRequestAndStartNew(
        int256 _paymentRequestId,
        uint256 _contractId,
        PaymentRequestTypeEnum _paymentRequestType
    ) 
        public 
        whenContractNotPaused 
        onlyRole(OPERATOR_ROLE) 
    {
        Contract storage currentContract = contractMustActive(_contractId);
        bool _chargePrepaidFee;
        uint256 _remainingLoan;
        uint256 _nextPhrasePenalty;
        uint256 _nextPhraseInterest;
        uint256 _dueDateTimestamp;

        // Check if number of requests is 0 => create new requests, if not then update current request as LATE or COMPLETE and create new requests
        PaymentRequest[] storage requests = contractPaymentRequestMapping[_contractId];
        if (requests.length > 0) {
            // not first phrase, get previous request
            PaymentRequest storage previousRequest = requests[requests.length - 1];
            
            // Validate: time must over due date of current payment
            require(block.timestamp >= previousRequest.dueDateTimestamp, '0'); // time-not-due

            // Validate: remaining loan must valid
            // require(previousRequest.remainingLoan == _remainingLoan, '1'); // remain
            _remainingLoan = previousRequest.remainingLoan;
            _nextPhrasePenalty = exchange.calculatePenalty(previousRequest,currentContract,penaltyRate);
            
            if(_paymentRequestType == PaymentRequestTypeEnum.INTEREST)
            {
                _dueDateTimestamp = PawnLib.add(previousRequest.dueDateTimestamp,PawnLib.calculatedueDateTimestampInterest(currentContract.terms.repaymentCycleType));
                _nextPhraseInterest = exchange.calculateInteres(currentContract); 
            } else {
               _dueDateTimestamp = PawnLib.add(previousRequest.dueDateTimestamp,PawnLib.calculatedueDateTimestampInterest(currentContract.terms.repaymentCycleType));
                _nextPhraseInterest = 0;  
            }

            if(_dueDateTimestamp >= currentContract.terms.contractEndDate) {
                _chargePrepaidFee = true;
            } else {
                _chargePrepaidFee = false;
            }

            // Validate: Due date timestamp of next payment request must not over contract due date
            require(_dueDateTimestamp <= currentContract.terms.contractEndDate, '2'); // contr-end
//            require(_dueDateTimestamp > previousRequest.dueDateTimestamp || _dueDateTimestamp == 0, '3'); // less-th-prev

            // update previous
            // check for remaining penalty and interest, if greater than zero then is Lated, otherwise is completed
            if (
                previousRequest.remainingInterest > 0 ||
                previousRequest.remainingPenalty > 0
            ) {
                previousRequest.status = PaymentRequestStatusEnum.LATE;

                // Adjust reputation score
                reputation.adjustReputationScore(
                    currentContract.terms.borrower,
                    IReputation.ReasonType.BR_LATE_PAYMENT
                );

                // Update late counter of contract
                currentContract.lateCount += 1;

                // Check for late threshold reach
                if (currentContract.terms.lateThreshold <= currentContract.lateCount) {
                    // Execute liquid
                    _liquidationExecution(
                        _contractId,
                        ContractLiquidedReasonType.LATE
                    );
                    return;
                }
            } else {
                previousRequest.status = PaymentRequestStatusEnum.COMPLETE;

                // Adjust reputation score
                reputation.adjustReputationScore(
                    currentContract.terms.borrower,
                    IReputation.ReasonType.BR_ONTIME_PAYMENT
                );
            }

            // Check for last repayment, if last repayment, all paid
            if (block.timestamp > currentContract.terms.contractEndDate) {
                if (previousRequest.remainingInterest + previousRequest.remainingPenalty + previousRequest.remainingLoan > 0) {
                    // unpaid => liquid
                    _liquidationExecution(
                        _contractId,
                        ContractLiquidedReasonType.UNPAID
                    );
                    return;
                } else {
                    // paid full => release collateral
                    _returnCollateralToBorrowerAndCloseContract(_contractId);
                    return;
                }
            }

            emit PaymentRequestEvent(-1,_contractId, previousRequest);
        } else {
            // Validate: remaining loan must valid
            // require(currentContract.terms.loanAmount == _remainingLoan, '4'); // remain
                _remainingLoan = currentContract.terms.loanAmount;
                _nextPhraseInterest = exchange.calculateInteres(currentContract);
                _nextPhrasePenalty = 0;
                _dueDateTimestamp = PawnLib.add(block.timestamp, PawnLib.calculatedueDateTimestampInterest(currentContract.terms.repaymentCycleType));

                if(currentContract.terms.repaymentCycleType == LoanDurationType.WEEK)
                {
                    if(currentContract.terms.contractEndDate - currentContract.terms.contractStartDate == 600)
                    {
                        _chargePrepaidFee = true;
                    } else {
                        _chargePrepaidFee = false;
                }
                } else {
                    if(currentContract.terms.contractEndDate - currentContract.terms.contractStartDate == 900)
                    {
                        _chargePrepaidFee = true;
                        
                    } else {
                        _chargePrepaidFee = false;
                    }
                }

            // Validate: Due date timestamp of next payment request must not over contract due date
            require(_dueDateTimestamp <= currentContract.terms.contractEndDate, '5'); // contr-end
            require(_dueDateTimestamp > currentContract.terms.contractStartDate || _dueDateTimestamp == 0, '6'); // less-th-prev
            require(block.timestamp < _dueDateTimestamp || _dueDateTimestamp == 0, '7'); // over

            // Check for last repayment, if last repayment, all paid
            if (block.timestamp > currentContract.terms.contractEndDate) {
                // paid full => release collateral
                _returnCollateralToBorrowerAndCloseContract(_contractId);
                return;
            }
        }

        // Create new payment request and store to contract
        PaymentRequest memory newRequest = PaymentRequest({
            requestId: requests.length,
            paymentRequestType: _paymentRequestType,
            remainingLoan: _remainingLoan,
            penalty: _nextPhrasePenalty,
            interest: _nextPhraseInterest,
            remainingPenalty: _nextPhrasePenalty,
            remainingInterest: _nextPhraseInterest,
            dueDateTimestamp: _dueDateTimestamp,
            status: PaymentRequestStatusEnum.ACTIVE,
            chargePrepaidFee: _chargePrepaidFee
        });
        requests.push(newRequest);
        emit PaymentRequestEvent(_paymentRequestId,_contractId, newRequest);
    }

    /** ===================================== 3.2. REPAYMENT ============================= */

    /**
        End lend period settlement and generate invoice for next period
     */
    function repayment(
        uint256 _contractId,
        uint256 _paidPenaltyAmount,
        uint256 _paidInterestAmount,
        uint256 _paidLoanAmount
    ) external whenContractNotPaused {
        // Get contract & payment request
        Contract storage _contract = contractMustActive(_contractId);
        PaymentRequest[] storage requests = contractPaymentRequestMapping[_contractId];
        require(requests.length > 0, '0');
        PaymentRequest storage _paymentRequest = requests[requests.length - 1];
        
        // Validation: Contract must not overdue
        require(block.timestamp <= _contract.terms.contractEndDate, '1'); // contr-over

        // Validation: current payment request must active and not over due
        require(_paymentRequest.status == PaymentRequestStatusEnum.ACTIVE, '2'); // not-act
        if (_paidPenaltyAmount + _paidInterestAmount > 0) {
            require(block.timestamp <= _paymentRequest.dueDateTimestamp, '3'); // over-due
        }

        // Calculate paid amount / remaining amount, if greater => get paid amount
        if (_paidPenaltyAmount > _paymentRequest.remainingPenalty) {
            _paidPenaltyAmount = _paymentRequest.remainingPenalty;
        }

        if (_paidInterestAmount > _paymentRequest.remainingInterest) {
            _paidInterestAmount = _paymentRequest.remainingInterest;
        }

        if (_paidLoanAmount > _paymentRequest.remainingLoan) {
            _paidLoanAmount = _paymentRequest.remainingLoan;
        }

        // Calculate fee amount based on paid amount
        uint256 _feePenalty = PawnLib.calculateSystemFee(
            _paidPenaltyAmount,
            _contract.terms.systemFeeRate,
            ZOOM
        );
        uint256 _feeInterest = PawnLib.calculateSystemFee(
            _paidInterestAmount,
            _contract.terms.systemFeeRate,
            ZOOM
        );

        uint256 _prepaidFee = 0;
        if (_paymentRequest.chargePrepaidFee) {
            _prepaidFee = PawnLib.calculateSystemFee(
                _paidLoanAmount,
                _contract.terms.prepaidFeeRate,
                ZOOM
            );
        }

        // Update paid amount on payment request
        _paymentRequest.remainingPenalty -= _paidPenaltyAmount;
        _paymentRequest.remainingInterest -= _paidInterestAmount;
        _paymentRequest.remainingLoan -= _paidLoanAmount;

        // emit event repayment
        emit RepaymentEvent(
            _contractId, 
            _paidPenaltyAmount, 
            _paidInterestAmount, 
            _paidLoanAmount, 
            _feePenalty, 
            _feeInterest, 
            _prepaidFee,
            _paymentRequest.requestId
        );

        // If remaining loan = 0 => paidoff => execute release collateral
        if (_paymentRequest.remainingLoan == 0 && _paymentRequest.remainingPenalty == 0 && _paymentRequest.remainingInterest == 0) {
            _returnCollateralToBorrowerAndCloseContract(_contractId);
        }

        if (_paidPenaltyAmount + _paidInterestAmount > 0) {
            // Transfer fee to fee wallet
            PawnLib.safeTransfer(
                _contract.terms.repaymentAsset,
                msg.sender,
                feeWallet,
                _feePenalty + _feeInterest
            );

            // Transfer penalty and interest to lender except fee amount
            PawnLib.safeTransfer(
                _contract.terms.repaymentAsset,
                msg.sender,
                _contract.terms.lender,
                _paidPenaltyAmount + _paidInterestAmount - _feePenalty - _feeInterest
            );
        }

        if (_paidLoanAmount > 0) {
            // Transfer loan amount and prepaid fee to lender
            PawnLib.safeTransfer(
                _contract.terms.loanAsset,
                msg.sender,
                _contract.terms.lender,
                _paidLoanAmount + _prepaidFee
            );
        }
    }

    /** ===================================== 3.3. LIQUIDITY & DEFAULT ============================= */

    function collateralRiskLiquidationExecution(
        uint256 _contractId
    ) 
        external 
        whenContractNotPaused
        onlyRole(OPERATOR_ROLE)
    {
        // Validate: Contract must active
        Contract storage _contract = contractMustActive(_contractId);

        uint256 collateralExchangeRate;
        uint256 loanExchangeRate;
        uint256 repaymentExchangeRate;
        uint256 rateUpdatedTime;
        (
            collateralExchangeRate,
            loanExchangeRate,
            repaymentExchangeRate,
            rateUpdatedTime
        ) = exchange.RateAndTimestamp(_contract);

        (
            uint256 remainingRepayment,
            uint256 remainingLoan
        ) = calculateRemainingLoanAndRepaymentFromContract(
                _contractId,
                _contract
            );

        uint256 valueOfRemainingRepayment = (repaymentExchangeRate * remainingRepayment) / ZOOM;
        uint256 valueOfRemainingLoan = (loanExchangeRate * remainingLoan) / ZOOM;
        uint256 valueOfCollateralLiquidationThreshold = (_contract.terms.collateralAmount * _contract.terms.liquidityThreshold) / (100 * ZOOM);

        require(valueOfRemainingLoan + valueOfRemainingRepayment >= valueOfCollateralLiquidationThreshold, '0'); // under-thres

        // Execute: call internal liquidation
        _liquidationExecution(_contractId, ContractLiquidedReasonType.RISK);
    }

    function calculateRemainingLoanAndRepaymentFromContract(
        uint256 _contractId,
        Contract storage _contract
    )
        internal
        view
        returns (uint256 remainingRepayment, uint256 remainingLoan)
    {
        // Validate: sum of unpaid interest, penalty and remaining loan in value must reach liquidation threshold of collateral value
        PaymentRequest[] storage requests = contractPaymentRequestMapping[_contractId];
        if (requests.length > 0) {
            // Have payment request
            PaymentRequest storage _paymentRequest = requests[requests.length - 1];
            remainingRepayment = _paymentRequest.remainingInterest + _paymentRequest.remainingPenalty;
            remainingLoan = _paymentRequest.remainingLoan;
        } else {
            // Haven't had payment request
            remainingRepayment = 0;
            remainingLoan = _contract.terms.loanAmount;
        }
    }

    function lateLiquidationExecution(uint256 _contractId)
        external
        whenContractNotPaused
    {
        // Validate: Contract must active
        Contract storage _contract = contractMustActive(_contractId);

        // validate: contract have lateCount == lateThreshold
        require(_contract.lateCount >= _contract.terms.lateThreshold, '0'); // not-reach

        // Execute: call internal liquidation
        _liquidationExecution(_contractId, ContractLiquidedReasonType.LATE);
    }

    function notPaidFullAtEndContractLiquidation(uint256 _contractId)
        external
        whenContractNotPaused
    {
        Contract storage _contract = contractMustActive(_contractId);
        // validate: current is over contract end date
        require(block.timestamp >= _contract.terms.contractEndDate, '0'); // due

        // validate: remaining loan, interest, penalty haven't paid in full
        (
            uint256 remainingRepayment,
            uint256 remainingLoan
        ) = calculateRemainingLoanAndRepaymentFromContract(
                _contractId,
                _contract
            );
        require(remainingRepayment + remainingLoan > 0, '1'); // paid
        
        // Execute: call internal liquidation
        _liquidationExecution(_contractId, ContractLiquidedReasonType.UNPAID);
    }

    function _liquidationExecution(
        uint256 _contractId,
        ContractLiquidedReasonType _reasonType
    ) internal {
        Contract storage _contract = contracts[_contractId];

        // Execute: calculate system fee of collateral and transfer collateral except system fee amount to lender
        uint256 _systemFeeAmount = PawnLib.calculateSystemFee(
            _contract.terms.collateralAmount,
            _contract.terms.systemFeeRate,
            ZOOM
        );
        uint256 _liquidAmount = _contract.terms.collateralAmount - _systemFeeAmount;

        // Execute: update status of contract to DEFAULT, collateral to COMPLETE
        _contract.status = ContractStatus.DEFAULT;
        PaymentRequest[] storage _paymentRequests = contractPaymentRequestMapping[_contractId];
        PaymentRequest storage _lastPaymentRequest = _paymentRequests[_paymentRequests.length - 1];
        _lastPaymentRequest.status = PaymentRequestStatusEnum.DEFAULT;
        Collateral storage _collateral = collaterals[_contract.collateralId];
        _collateral.status = CollateralStatus.COMPLETED;

        // Emit Event ContractLiquidedEvent & PaymentRequest event
        emit ContractLiquidedEvent(
            _contractId,
            _liquidAmount,
            _systemFeeAmount,
            _reasonType
        );

        emit PaymentRequestEvent(-1,_contractId, _lastPaymentRequest);

        // Transfer to lender liquid amount
        PawnLib.safeTransfer(
            _contract.terms.collateralAsset,
            address(this),
            _contract.terms.lender,
            _liquidAmount
        );

        // Transfer to system fee wallet fee amount
        PawnLib.safeTransfer(
            _contract.terms.collateralAsset,
            address(this),
            feeWallet,
            _systemFeeAmount
        );

        // Adjust reputation score
        reputation.adjustReputationScore(
            _contract.terms.borrower,
            IReputation.ReasonType.BR_LATE_PAYMENT
        );
        reputation.adjustReputationScore(
            _contract.terms.borrower,
            IReputation.ReasonType.BR_CONTRACT_DEFAULTED
        );
    }

    function _returnCollateralToBorrowerAndCloseContract(uint256 _contractId)
        internal
    {
        Contract storage _contract = contracts[_contractId];

        // Execute: Update status of contract to COMPLETE, collateral to COMPLETE
        _contract.status = ContractStatus.COMPLETED;
        PaymentRequest[] storage _paymentRequests = contractPaymentRequestMapping[_contractId];
        PaymentRequest storage _lastPaymentRequest = _paymentRequests[_paymentRequests.length - 1];
        _lastPaymentRequest.status = PaymentRequestStatusEnum.COMPLETE;
        Collateral storage _collateral = collaterals[_contract.collateralId];
        _collateral.status = CollateralStatus.COMPLETED;

        // Emit event ContractCompleted
        emit LoanContractCompletedEvent(_contractId);
        emit PaymentRequestEvent(-1,_contractId, _lastPaymentRequest);

        // Execute: Transfer collateral to borrower
        PawnLib.safeTransfer(
            _contract.terms.collateralAsset,
            address(this),
            _contract.terms.borrower,
            _contract.terms.collateralAmount
        );

        // Adjust reputation score
        reputation.adjustReputationScore(
            _contract.terms.borrower,
            IReputation.ReasonType.BR_ONTIME_PAYMENT
        );
        reputation.adjustReputationScore(
            _contract.terms.borrower,
            IReputation.ReasonType.BR_CONTRACT_COMPLETE
        );
    }

    function findContractOfCollateral(
        uint256 _collateralId,
        uint256 _contractStart,
        uint256 _contractEnd
    ) external view returns (int256 _idx) {
        _idx = -1;
        uint256 endIdx = _contractEnd;
        if (_contractEnd >= numberContracts - 1) {
            endIdx = numberContracts - 1;
        }
        for (uint256 i = _contractStart; i < endIdx; i++) {
            Contract storage mContract = contracts[i];
            if (mContract.collateralId == _collateralId) {
                _idx = int256(i);
                break;
            }
        }
    }
}