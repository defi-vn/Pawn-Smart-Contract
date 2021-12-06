// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./PawnNFTModel.sol";
import "./IPawnNFT.sol";
import "./PawnNFTLib.sol";
import "./ILoanNFT.sol";

contract LoanNFTContract is PawnNFTModel, ILoanNFT {

    using CountersUpgradeable for CountersUpgradeable.Counter;
    using AddressUpgradeable for address;
    using SafeMathUpgradeable for uint256;

    IPawnNFT public pawnContract;

    // Total collateral
    CountersUpgradeable.Counter public numberCollaterals;

    // Mapping collateralId => Collateral
    mapping(uint256 => Collateral_NFT) public collaterals;

    // Total offer
    CountersUpgradeable.Counter public numberOffers;

    // Mapping collateralId => list offer of collateral
    mapping(uint256 => CollateralOfferList_NFT) public collateralOffersMapping;

    // Total contract
    uint256 public numberContracts;

    // Mapping contractId => Contract
    mapping(uint256 => Contract_NFT) public contracts;

    // Mapping contract Id => array payment request
    mapping(uint256 => PaymentRequest_NFT[])
        public contractPaymentRequestMapping;

    // /**
    //  * @dev initialize function
    //  * @param _zoom is coefficient used to represent risk params
    //  */
    // function _LoanContract_NFT_init(uint32 _zoom) public initializer {
    //     initialize(_zoom);
    // }

    // function setPawnContract(address _pawnAddress)
    //     external
    //     onlyRole(DEFAULT_ADMIN_ROLE)
    // {
    //     pawnContract = IPawnNFT(_pawnAddress);
    //     grantRole(OPERATOR_ROLE, _pawnAddress);
    // }

    /** ================================ CREATE LOAN CONTRACT ============================= */

    function createContract(
        ContractRawData_NFT calldata contractData,
        uint256 _UID
    ) external override onlyOperator returns (uint256 _idx) {
        (
            ,
            uint256 systemFeeRate,
            uint256 penaltyRate,
            uint256 prepaidFeeRate,
            uint256 lateThreshold
        ) = HubInterface(hubContract).getPawnNFTConfig();
        //get Offer
        CollateralOfferList_NFT
            storage collateralOfferList = collateralOffersMapping[
                contractData._nftCollateralId
            ];
        Offer_NFT storage _offer = collateralOfferList.offerMapping[
            contractData._offerId
        ];

        _idx = numberContracts;
        Contract_NFT storage newContract = contracts[_idx];
        newContract.nftCollateralId = contractData._nftCollateralId;
        newContract.offerId = contractData._offerId;
        newContract.status = ContractStatus_NFT.ACTIVE;
        newContract.lateCount = 0;
        newContract.terms.borrower = contractData._collateral.owner;
        newContract.terms.lender = contractData._lender;
        newContract.terms.nftTokenId = contractData._collateral.nftTokenId;
        newContract.terms.nftCollateralAsset = contractData
            ._collateral
            .nftContract;
        newContract.terms.nftCollateralAmount = contractData
            ._collateral
            .nftTokenQuantity;
        newContract.terms.loanAsset = contractData._collateral.loanAsset;
        newContract.terms.loanAmount = contractData._loanAmount;
        newContract.terms.repaymentCycleType = contractData._repaymentCycleType;
        newContract.terms.repaymentAsset = contractData._repaymentAsset;
        newContract.terms.interest = contractData._interest;
        newContract.terms.liquidityThreshold = contractData._liquidityThreshold;
        newContract.terms.contractStartDate = block.timestamp;
        newContract.terms.contractEndDate =
            block.timestamp +
            PawnNFTLib.calculateContractDuration(
                _offer.loanDurationType,
                _offer.duration
            );
        newContract.terms.lateThreshold = lateThreshold;
        newContract.terms.systemFeeRate = systemFeeRate;
        newContract.terms.penaltyRate = penaltyRate;
        newContract.terms.prepaidFeeRate = prepaidFeeRate;
        ++numberContracts;

        emit LoanContractCreatedEvent_NFT(
            contractData.exchangeRate,
            msg.sender,
            _idx,
            newContract,
            _UID
        );

        // chot ky dau tien khi tao contract
        closePaymentRequestAndStarNew(
            0,
            _idx,
            PaymentRequestTypeEnum_NFT.INTEREST
        );
    }

    function closePaymentRequestAndStarNew(
        int256 _paymentRequestId,
        uint256 _contractId,
        // uint256 _remainingLoan,
        // uint256 _nextPhrasePenalty,
        // uint256 _nextPhraseInterest,
        // uint256 _dueDateTimestamp,
        // bool _chargePrepaidFee
        PaymentRequestTypeEnum_NFT _paymentRequestType
    ) public whenNotPaused onlyOperator {
        // get contract
        Contract_NFT storage currentContract = contractMustActive(_contractId);

        bool _chargePrepaidFee;
        uint256 _remainingLoan;
        uint256 _nextPhrasePenalty;
        uint256 _nextPhraseInterest;
        uint256 _dueDateTimestamp;
        // Check if number of requests is 0 => create new requests, if not then update current request as LATE or COMPLETE and create new requests
        PaymentRequest_NFT[] storage requests = contractPaymentRequestMapping[
            _contractId
        ];
        if (requests.length > 0) {
            // not first phrase, get previous request
            PaymentRequest_NFT storage previousRequest = requests[
                requests.length - 1
            ];

            // Validate: time must over due date of current payment
            require(block.timestamp >= previousRequest.dueDateTimestamp, "0");

            // Validate: remaining loan must valid
            // require(previousRequest.remainingLoan == _remainingLoan, "1");
            _remainingLoan = previousRequest.remainingLoan;
            // _nextPhrasePenalty = exchange.calculatePenalty_NFT(
            //     previousRequest,
            //     currentContract,
            //     penaltyRate
            // );
            (, , uint256 penaltyRate, , ) = HubInterface(hubContract)
                .getPawnNFTConfig();
            _nextPhrasePenalty = IExchange(getExchange()).calculatePenalty_NFT(
                previousRequest,
                currentContract,
                penaltyRate
            );

            uint256 _timeStamp;
            if (_paymentRequestType == PaymentRequestTypeEnum_NFT.INTEREST) {
                _timeStamp = PawnNFTLib.calculatedueDateTimestampInterest(
                    currentContract.terms.repaymentCycleType
                );

                // _nextPhraseInterest = exchange.calculateInterest_NFT(
                //     _remainingLoan,
                //     currentContract
                // );
                _nextPhraseInterest = IExchange(getExchange())
                    .calculateInterest_NFT(_remainingLoan, currentContract);
            }
            if (_paymentRequestType == PaymentRequestTypeEnum_NFT.OVERDUE) {
                _timeStamp = PawnNFTLib.calculatedueDateTimestampPenalty(
                    currentContract.terms.repaymentCycleType
                );

                _nextPhraseInterest = 0;
            }

            (, _dueDateTimestamp) = SafeMathUpgradeable.tryAdd(
                previousRequest.dueDateTimestamp,
                _timeStamp
            );

            _chargePrepaidFee = PawnNFTLib.isPrepaidChargeRequired(
                currentContract.terms.repaymentCycleType,
                previousRequest.dueDateTimestamp,
                currentContract.terms.contractEndDate
            );
            // Validate: Due date timestamp of next payment request must not over contract due date
            require(
                _dueDateTimestamp <= currentContract.terms.contractEndDate,
                "2"
            );
            // require(
            //     _dueDateTimestamp > previousRequest.dueDateTimestamp ||
            //         _dueDateTimestamp == 0,
            //     "3"
            // );

            // update previous
            // check for remaining penalty and interest, if greater than zero then is Lated, otherwise is completed
            if (
                previousRequest.remainingInterest > 0 ||
                previousRequest.remainingPenalty > 0
            ) {
                previousRequest.status = PaymentRequestStatusEnum_NFT.LATE;
                // Update late counter of contract
                currentContract.lateCount += 1;

                // Adjust reputation score
                // reputation.adjustReputationScore(
                //     currentContract.terms.borrower,
                //     IReputation.ReasonType.BR_LATE_PAYMENT
                // );

                IReputation(getReputation()).adjustReputationScore(
                    currentContract.terms.borrower,
                    IReputation.ReasonType.BR_LATE_PAYMENT
                );

                emit CountLateCount(
                    currentContract.terms.lateThreshold,
                    currentContract.lateCount
                );

                // Check for late threshold reach
                if (
                    currentContract.terms.lateThreshold <=
                    currentContract.lateCount
                ) {
                    // Execute liquid

                    emit PaymentRequestEvent_NFT(
                        -1,
                        _contractId,
                        previousRequest
                    );

                    _liquidationExecution(
                        _contractId,
                        ContractLiquidedReasonType_NFT.LATE
                    );
                    return;
                }
            } else {
                previousRequest.status = PaymentRequestStatusEnum_NFT.COMPLETE;

                // Adjust reputation score
                // reputation.adjustReputationScore(
                //     currentContract.terms.borrower,
                //     IReputation.ReasonType.BR_ONTIME_PAYMENT
                // );

                IReputation(getReputation()).adjustReputationScore(
                    currentContract.terms.borrower,
                    IReputation.ReasonType.BR_ONTIME_PAYMENT
                );
            }

            // Check for last repayment, if last repayment, all paid
            if (block.timestamp > currentContract.terms.contractEndDate) {
                if (
                    previousRequest.remainingInterest +
                        previousRequest.remainingPenalty +
                        previousRequest.remainingLoan >
                    0
                ) {
                    // unpaid => liquid
                    _liquidationExecution(
                        _contractId,
                        ContractLiquidedReasonType_NFT.UNPAID
                    );
                    return;
                } else {
                    // paid full => release collateral
                    _returnCollateralToBorrowerAndCloseContract(_contractId);
                    return;
                }
            }

            emit PaymentRequestEvent_NFT(-1, _contractId, previousRequest);
        } else {
            // Validate: remaining loan must valid
            // require(currentContract.terms.loanAmount == _remainingLoan, "4");
            _remainingLoan = currentContract.terms.loanAmount;
            // _nextPhraseInterest = exchange.calculateInterest_NFT(
            //     _remainingLoan,
            //     currentContract
            // );
            _nextPhraseInterest = IExchange(getExchange())
                .calculateInterest_NFT(_remainingLoan, currentContract);
            _nextPhrasePenalty = 0;
            // Validate: Due date timestamp of next payment request must not over contract due date
            (, _dueDateTimestamp) = SafeMathUpgradeable.tryAdd(
                block.timestamp,
                PawnNFTLib.calculatedueDateTimestampInterest(
                    currentContract.terms.repaymentCycleType
                )
            );
            _chargePrepaidFee = PawnNFTLib.isPrepaidChargeRequired(
                currentContract.terms.repaymentCycleType,
                currentContract.terms.contractStartDate,
                currentContract.terms.contractEndDate
            );
            require(
                _dueDateTimestamp <= currentContract.terms.contractEndDate,
                "5"
            );
            require(
                _dueDateTimestamp > currentContract.terms.contractStartDate ||
                    _dueDateTimestamp == 0,
                "6"
            );
            require(
                block.timestamp < _dueDateTimestamp || _dueDateTimestamp == 0,
                "7"
            );

            // Check for last repayment, if last repayment, all paid
            if (block.timestamp > currentContract.terms.contractEndDate) {
                // paid full => release collateral
                _returnCollateralToBorrowerAndCloseContract(_contractId);
                return;
            }
        }

        // Create new payment request and store to contract
        PaymentRequest_NFT memory newRequest = PaymentRequest_NFT({
            requestId: requests.length,
            paymentRequestType: _paymentRequestType,
            remainingLoan: _remainingLoan,
            penalty: _nextPhrasePenalty,
            interest: _nextPhraseInterest,
            remainingPenalty: _nextPhrasePenalty,
            remainingInterest: _nextPhraseInterest,
            dueDateTimestamp: _dueDateTimestamp,
            status: PaymentRequestStatusEnum_NFT.ACTIVE,
            chargePrepaidFee: _chargePrepaidFee
        });
        requests.push(newRequest);
        emit PaymentRequestEvent_NFT(
            _paymentRequestId,
            _contractId,
            newRequest
        );
    }

    /**
     * @dev get Contract must active
     * @param  _contractId is id of contract
     */
    function contractMustActive(uint256 _contractId)
        internal
        view
        returns (Contract_NFT storage _contract)
    {
        // Validate: Contract must active
        _contract = contracts[_contractId];
        require(_contract.status == ContractStatus_NFT.ACTIVE, "0");
    }

    /**
     * @dev Perform contract liquidation
     * @param  _contractId is id of contract
     * @param  _reasonType is type of reason for liquidation of the contract
     */
    function _liquidationExecution(
        uint256 _contractId,
        ContractLiquidedReasonType_NFT _reasonType
    ) internal {
        Contract_NFT storage _contract = contracts[_contractId];

        // Execute: update status of contract to DEFAULT, collateral to COMPLETE
        _contract.status = ContractStatus_NFT.DEFAULT;
        PaymentRequest_NFT[]
            storage _paymentRequests = contractPaymentRequestMapping[
                _contractId
            ];

        if (_reasonType != ContractLiquidedReasonType_NFT.LATE) {
            PaymentRequest_NFT storage _lastPaymentRequest = _paymentRequests[
                _paymentRequests.length - 1
            ];
            _lastPaymentRequest.status = PaymentRequestStatusEnum_NFT.DEFAULT;
        }

        Collateral_NFT storage _collateral = collaterals[
            _contract.nftCollateralId
        ];
        // _collateral.status = CollateralStatus_NFT.COMPLETED;

        // PawnContract_NFT.updateCollateralStatus(
        //     _contract.nftCollateralId,
        //     CollateralStatus_NFT.COMPLETED
        // );

        ILoanNFT(getPawnNFT()).updateCollateralStatus(
            _contract.nftCollateralId,
            CollateralStatus_NFT.COMPLETED
        );

        ContractLiquidationData_NFT memory liquidationData;

        {
            // (address _evaluationContract, ) = IDFY_Physical_NFTs(
            //     _collateral.nftContract
            // ).getEvaluationOfToken(_collateral.nftTokenId);

            // (, , , , address token, , ) = AssetEvaluation(_evaluationContract)
            //     .tokenIdByEvaluation(_collateral.nftTokenId);

            (address token, , , ) = IDFY_Hard_Evaluation(getEvaluation())
                .getEvaluationWithTokenId(
                    _collateral.nftContract,
                    _collateral.nftTokenId
                );

            // (
            //     uint256 _tokenEvaluationRate,
            //     uint256 _loanExchangeRate,
            //     uint256 _repaymentExchangeRate,
            //     uint256 _rateUpdateTime
            // ) = exchange.RateAndTimestamp_NFT(_contract, token);

            (
                uint256 _tokenEvaluationRate,
                uint256 _loanExchangeRate,
                uint256 _repaymentExchangeRate,
                uint256 _rateUpdateTime
            ) = IExchange(getExchange()).RateAndTimestamp_NFT(_contract, token);

            // Emit Event ContractLiquidedEvent
            liquidationData = ContractLiquidationData_NFT(
                _contractId,
                _tokenEvaluationRate,
                _loanExchangeRate,
                _repaymentExchangeRate,
                _rateUpdateTime,
                _reasonType
            );
        }

        emit ContractLiquidedEvent_NFT(liquidationData);
        // Transfer to lender collateral

        (
            ,
            ,
            ,
            IDFY_Hard_Evaluation.CollectionStandard _collectionStandard
        ) = IDFY_Hard_Evaluation(getEvaluation()).getEvaluationWithTokenId(
                _collateral.nftContract,
                _collateral.nftTokenId
            );
        PawnNFTLib.safeTranferNFTToken(
            _contract.terms.nftCollateralAsset,
            address(this),
            _contract.terms.lender,
            _contract.terms.nftTokenId,
            _contract.terms.nftCollateralAmount,
            _collectionStandard
        );

        // Adjust reputation score
        // reputation.adjustReputationScore(
        //     _contract.terms.borrower,
        //     IReputation.ReasonType.BR_LATE_PAYMENT
        // );
        // reputation.adjustReputationScore(
        //     _contract.terms.borrower,
        //     IReputation.ReasonType.BR_CONTRACT_DEFAULTED
        // );

        IReputation(getReputation()).adjustReputationScore(
            _contract.terms.borrower,
            IReputation.ReasonType.BR_LATE_PAYMENT
        );

        IReputation(getReputation()).adjustReputationScore(
            _contract.terms.borrower,
            IReputation.ReasonType.BR_CONTRACT_DEFAULTED
        );
    }

    /**
     * @dev return collateral to borrower and close contract
     * @param  _contractId is id of contract
     */
    function _returnCollateralToBorrowerAndCloseContract(uint256 _contractId)
        internal
    {
        Contract_NFT storage _contract = contracts[_contractId];

        // Execute: Update status of contract to COMPLETE, collateral to COMPLETE
        _contract.status = ContractStatus_NFT.COMPLETED;
        PaymentRequest_NFT[]
            storage _paymentRequests = contractPaymentRequestMapping[
                _contractId
            ];
        PaymentRequest_NFT storage _lastPaymentRequest = _paymentRequests[
            _paymentRequests.length - 1
        ];
        _lastPaymentRequest.status = PaymentRequestStatusEnum_NFT.COMPLETE;

        Collateral_NFT storage _collateral = collaterals[
            _contract.nftCollateralId
        ];
        // _collateral.status = CollateralStatus_NFT.COMPLETED;
        // PawnContract_NFT.updateCollateralStatus(
        //     _contract.nftCollateralId,
        //     CollateralStatus_NFT.COMPLETED
        // );
        ILoanNFT(getPawnNFT()).updateCollateralStatus(
            _contract.nftCollateralId,
            CollateralStatus_NFT.COMPLETED
        );

        // Emit Event ContractLiquidedEvent
        emit LoanContractCompletedEvent_NFT(_contractId);
        emit PaymentRequestEvent_NFT(-1, _contractId, _lastPaymentRequest);

        // Execute: Transfer collateral to borrower

        (
            ,
            ,
            ,
            IDFY_Hard_Evaluation.CollectionStandard _collectionStandard
        ) = IDFY_Hard_Evaluation(getEvaluation()).getEvaluationWithTokenId(
                _collateral.nftContract,
                _collateral.nftTokenId
            );
        PawnNFTLib.safeTranferNFTToken(
            _contract.terms.nftCollateralAsset,
            address(this),
            _contract.terms.borrower,
            _contract.terms.nftTokenId,
            _contract.terms.nftCollateralAmount,
            _collectionStandard
        );

        // Adjust reputation score
        // reputation.adjustReputationScore(
        //     _contract.terms.borrower,
        //     IReputation.ReasonType.BR_ONTIME_PAYMENT
        // );
        // reputation.adjustReputationScore(
        //     _contract.terms.borrower,
        //     IReputation.ReasonType.BR_CONTRACT_COMPLETE
        // );

        IReputation(getReputation()).adjustReputationScore(
            _contract.terms.borrower,
            IReputation.ReasonType.BR_ONTIME_PAYMENT
        );

        IReputation(getReputation()).adjustReputationScore(
            _contract.terms.borrower,
            IReputation.ReasonType.BR_CONTRACT_COMPLETE
        );
    }

    /**
     * @dev the borrower repays the debt
     * @param  _contractId is id of contract
     * @param  _paidPenaltyAmount is paid penalty amount
     * @param  _paidInterestAmount is paid interest amount
     * @param  _paidLoanAmount is paid loan amount
     */
    function repayment(
        uint256 _contractId,
        uint256 _paidPenaltyAmount,
        uint256 _paidInterestAmount,
        uint256 _paidLoanAmount,
        uint256 _UID
    ) external whenNotPaused {
        // Get contract & payment request
        Contract_NFT storage _contract = contractMustActive(_contractId);
        PaymentRequest_NFT[] storage requests = contractPaymentRequestMapping[
            _contractId
        ];
        require(requests.length > 0, "0");
        PaymentRequest_NFT storage _paymentRequest = requests[
            requests.length - 1
        ];

        // Validation: Contract must not overdue
        require(block.timestamp <= _contract.terms.contractEndDate, "1");

        // Validation: current payment request must active and not over due
        require(
            _paymentRequest.status == PaymentRequestStatusEnum_NFT.ACTIVE,
            "2"
        );
        if (_paidPenaltyAmount + _paidInterestAmount > 0) {
            require(block.timestamp <= _paymentRequest.dueDateTimestamp, "3");
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

        (uint256 ZOOM, , , , ) = HubInterface(hubContract).getPawnNFTConfig();
        uint256 _feePenalty = PawnNFTLib.calculateSystemFee(
            _paidPenaltyAmount,
            _contract.terms.systemFeeRate,
            ZOOM
        );
        uint256 _feeInterest = PawnNFTLib.calculateSystemFee(
            _paidInterestAmount,
            _contract.terms.systemFeeRate,
            ZOOM
        );

        uint256 _prepaidFee = 0;
        if (_paymentRequest.chargePrepaidFee) {
            _prepaidFee = PawnNFTLib.calculateSystemFee(
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
        // emit RepaymentEvent_NFT(
        //     _contractId,
        //     _paidPenaltyAmount,
        //     _paidInterestAmount,
        //     _paidLoanAmount,
        //     _feePenalty,
        //     _feeInterest,
        //     _prepaidFee,
        //     _paymentRequest.requestId,
        //     _UID
        // );
        RepaymentEventData_NFT memory repaymentData = RepaymentEventData_NFT(
            _contractId,
            _paidPenaltyAmount,
            _paidInterestAmount,
            _paidLoanAmount,
            _feePenalty,
            _feeInterest,
            _prepaidFee,
            _paymentRequest.requestId,
            _UID
        );
        emit RepaymentEvent_NFT(repaymentData);

        // If remaining loan = 0 => paidoff => execute release collateral
        if (
            _paymentRequest.remainingLoan == 0 &&
            _paymentRequest.remainingPenalty == 0 &&
            _paymentRequest.remainingInterest == 0
        ) _returnCollateralToBorrowerAndCloseContract(_contractId);

        uint256 _totalFee;
        uint256 _totalTransferAmount;
        uint256 total = _paidPenaltyAmount + _paidInterestAmount;
        (address feeWallet, ) = HubInterface(hubContract).getSystemConfig();
        {
            if (total > 0) {
                // Transfer fee to fee wallet
                _totalFee = _feePenalty + _feeInterest;
                PawnNFTLib.safeTransfer(
                    _contract.terms.repaymentAsset,
                    msg.sender,
                    feeWallet,
                    _totalFee
                );

                // Transfer penalty and interest to lender except fee amount
                _totalTransferAmount = total - _feePenalty - _feeInterest;
                PawnNFTLib.safeTransfer(
                    _contract.terms.repaymentAsset,
                    msg.sender,
                    _contract.terms.lender,
                    _totalTransferAmount
                );
            }
        }
        {
            if (_paidLoanAmount > 0) {
                // Transfer loan amount and prepaid fee to lender
                _totalTransferAmount = _paidLoanAmount + _prepaidFee;
                PawnNFTLib.safeTransfer(
                    _contract.terms.loanAsset,
                    msg.sender,
                    _contract.terms.lender,
                    _totalTransferAmount
                );
            }
        }
    }

    function collateralRiskLiquidationExecution(
        // uint256 _collateralPerRepaymentTokenExchangeRate,
        // uint256 _collateralPerLoanAssetExchangeRate
        uint256 _contractId
    ) external whenNotPaused onlyOperator {
        // Validate: Contract must active
        Contract_NFT storage _contract = contractMustActive(_contractId);
        Collateral_NFT storage _collateral = collaterals[
            _contract.nftCollateralId
        ];

        //get Address of EvaluationContract
        // (address _evaluationContract, ) = IDFY_Physical_NFTs(
        //     _collateral.nftContract
        // ).getEvaluationOfToken(_collateral.nftTokenId);

        // get Evaluation from address of EvaluationContract
        // (, , , , address token, uint256 price, ) = AssetEvaluation(
        //     _evaluationContract
        // ).tokenIdByEvaluation(_collateral.nftTokenId);

        (address token, uint256 price, , ) = IDFY_Hard_Evaluation(
            getEvaluation()
        ).getEvaluationWithTokenId(
                _collateral.nftContract,
                _collateral.nftTokenId
            );

        (
            uint256 remainingRepayment,
            uint256 remainingLoan
        ) = calculateRemainingLoanAndRepaymentFromContract(
                _contractId,
                _contract
            );
        // (
        //     uint256 _collateralPerRepaymentTokenExchangeRate,
        //     uint256 _collateralPerLoanAssetExchangeRate
        // ) = exchange.collateralPerRepaymentAndLoanTokenExchangeRate_NFT(
        //         _contract,
        //         token
        //     );

        (
            uint256 _collateralPerRepaymentTokenExchangeRate,
            uint256 _collateralPerLoanAssetExchangeRate
        ) = IExchange(getExchange())
                .collateralPerRepaymentAndLoanTokenExchangeRate_NFT(
                    _contract,
                    token
                );
        {
            (uint256 ZOOM, , , , ) = HubInterface(hubContract)
                .getPawnNFTConfig();
            uint256 valueOfRemainingRepayment = (_collateralPerRepaymentTokenExchangeRate *
                    remainingRepayment) / (ZOOM * 10**5);
            uint256 valueOfRemainingLoan = (_collateralPerLoanAssetExchangeRate *
                    remainingLoan) / (ZOOM * 10**5);
            uint256 valueOfCollateralLiquidationThreshold = (price *
                _contract.terms.liquidityThreshold) / (100 * ZOOM);

            uint256 total = valueOfRemainingLoan + valueOfRemainingRepayment;
            bool valid = total > valueOfCollateralLiquidationThreshold;
            require(valid, "0");
        }

        // Execute: call internal liquidation
        _liquidationExecution(_contractId, ContractLiquidedReasonType_NFT.RISK);
    }

    /**
     * @dev liquidate the contract if the borrower has not paid in full at the end of the contract
     * @param _contractId is id of contract
     */
    function lateLiquidationExecution(uint256 _contractId)
        external
        whenNotPaused
    {
        // Validate: Contract must active
        Contract_NFT storage _contract = contractMustActive(_contractId);

        // validate: contract have lateCount == lateThreshold
        require(_contract.lateCount >= _contract.terms.lateThreshold, "0");

        // Execute: call internal liquidation
        _liquidationExecution(_contractId, ContractLiquidedReasonType_NFT.LATE);
    }

    /**
     * @dev liquidate the contract if the borrower has not paid in full at the end of the contract
     * @param _contractId is id of contract
     */
    function notPaidFullAtEndContractLiquidation(uint256 _contractId)
        external
        whenNotPaused
    {
        Contract_NFT storage _contract = contractMustActive(_contractId);
        // validate: current is over contract end date
        require(block.timestamp >= _contract.terms.contractEndDate, "0");

        // validate: remaining loan, interest, penalty haven't paid in full
        (
            uint256 remainingRepayment,
            uint256 remainingLoan
        ) = calculateRemainingLoanAndRepaymentFromContract(
                _contractId,
                _contract
            );

        require(remainingRepayment + remainingLoan > 0, "1");

        // Execute: call internal liquidation
        _liquidationExecution(
            _contractId,
            ContractLiquidedReasonType_NFT.UNPAID
        );
    }

    function calculateRemainingLoanAndRepaymentFromContract(
        uint256 _contractId,
        Contract_NFT storage _contract
    )
        internal
        view
        returns (uint256 remainingRepayment, uint256 remainingLoan)
    {
        // Validate: sum of unpaid interest, penalty and remaining loan in value must reach liquidation threshold of collateral value
        PaymentRequest_NFT[] storage requests = contractPaymentRequestMapping[
            _contractId
        ];
        if (requests.length > 0) {
            // Have payment request
            PaymentRequest_NFT storage _paymentRequest = requests[
                requests.length - 1
            ];
            remainingRepayment =
                _paymentRequest.remainingInterest +
                _paymentRequest.remainingPenalty;
            remainingLoan = _paymentRequest.remainingLoan;
        } else {
            // Haven't had payment request
            remainingRepayment = 0;
            remainingLoan = _contract.terms.loanAmount;
        }
    }

    /**========================= */

    function signature() public pure override returns (bytes4) {
        return type(IPawnNFT).interfaceId;
    }

    /**=========================== */

    function getPawnNFT() internal view returns (address _PawnAddress) {
        (_PawnAddress, ) = HubInterface(hubContract).getContractAddress(
            type(ILoanNFT).interfaceId
        );
    }

    /** ==================== User-reviews related functions ==================== */
    function getContractInfoForReview(uint256 contractId)
        external
        view
        override
        returns (
            address borrower,
            address lender,
            ContractStatus status
        )
    {
        Contract storage _contract = contracts[contractId];
        borrower = _contract.terms.borrower;
        lender = _contract.terms.lender;
        status = _contract.status;
    }
}
