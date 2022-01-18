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

    // Mapping collateralId => Collateral
    //  mapping(uint256 => IPawnNFTBase.NFTCollateral) public collaterals;

    // Mapping collateralId => list offer of collateral
    mapping(uint256 => IPawnNFTBase.NFTCollateralOfferList)
        public collateralOffersMapping;

    // Total contract
    uint256 public numberContracts;

    // Mapping contractId => Contract
    mapping(uint256 => IPawnNFTBase.NFTLoanContract) public contracts;

    // Mapping contract Id => array payment request
    mapping(uint256 => IPawnNFTBase.NFTPaymentRequest[])
        public contractPaymentRequestMapping;

    /** ==================== Standard interface function implementations ==================== */

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(PawnNFTModel, IERC165Upgradeable)
        returns (bool)
    {
        return
            interfaceId == type(ILoanNFT).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function signature() external pure override returns (bytes4) {
        return type(ILoanNFT).interfaceId;
    }

    /** ==================== NFT Loan contract operations ==================== */

    function createContract(
        IPawnNFTBase.NFTContractRawData calldata contractData
    ) external override whenContractNotPaused returns (uint256 _idx) {
        require(
            (_msgSender() == getPawnNFTContract() &&
                IAccessControlUpgradeable(contractHub).hasRole(
                    HubRoles.INTERNAL_CONTRACT,
                    _msgSender()
                )) ||
                IAccessControlUpgradeable(contractHub).hasRole(
                    HubRoles.OPERATOR_ROLE,
                    _msgSender()
                ),
            "Pawn contract (internal) or Operator"
        );
        (
            ,
            uint256 systemFeeRate,
            uint256 penaltyRate,
            uint256 prepaidFeeRate,
            uint256 lateThreshold
        ) = HubInterface(contractHub).getPawnNFTConfig();

        _idx = numberContracts;
        IPawnNFTBase.NFTLoanContract storage newContract = contracts[_idx];
        newContract.nftCollateralId = contractData.nftCollateralId;
        newContract.offerId = contractData.offerId;
        newContract.status = IEnums.ContractStatus.ACTIVE;
        newContract.lateCount = 0;
        newContract.terms.borrower = contractData.collateral.owner;
        newContract.terms.lender = contractData.lender;
        newContract.terms.nftTokenId = contractData.collateral.nftTokenId;
        newContract.terms.nftCollateralAsset = contractData
            .collateral
            .nftContract;
        newContract.terms.nftCollateralAmount = contractData
            .collateral
            .nftTokenQuantity;
        newContract.terms.loanAsset = contractData.collateral.loanAsset;
        newContract.terms.loanAmount = contractData.loanAmount;
        newContract.terms.repaymentCycleType = contractData.repaymentCycleType;
        newContract.terms.repaymentAsset = contractData.repaymentAsset;
        newContract.terms.interest = contractData.interest;
        //   newContract.terms.liquidityThreshold = contractData.liquidityThreshold;
        newContract.terms.contractStartDate = block.timestamp;
        newContract.terms.contractEndDate =
            block.timestamp +
            PawnNFTLib.calculateContractDuration(
                contractData.repaymentCycleType,
                contractData.loanDurationQty
            );
        newContract.terms.lateThreshold = lateThreshold;
        newContract.terms.systemFeeRate = systemFeeRate;
        newContract.terms.penaltyRate = penaltyRate;
        newContract.terms.prepaidFeeRate = prepaidFeeRate;
        ++numberContracts;

        emit LoanContractCreatedEvent(
            contractData.exchangeRate,
            msg.sender,
            _idx,
            newContract
        );

        // chot ky dau tien khi tao contract
        closePaymentRequestAndStarNew(
            0,
            _idx,
            IEnums.PaymentRequestTypeEnum.INTEREST
        );
    }

    function closePaymentRequestAndStarNew(
        int256 paymentRequestId,
        uint256 contractId,
        IEnums.PaymentRequestTypeEnum paymentRequestType
    ) public whenNotPaused {
        require(
            (_msgSender() == getPawnNFTContract() &&
                IAccessControlUpgradeable(contractHub).hasRole(
                    HubRoles.INTERNAL_CONTRACT,
                    _msgSender()
                )) ||
                IAccessControlUpgradeable(contractHub).hasRole(
                    HubRoles.OPERATOR_ROLE,
                    _msgSender()
                ),
            "Pawn contract (internal) or Operator"
        );
        // get contract
        IPawnNFTBase.NFTLoanContract
            storage currentContract = contractMustActive(contractId);

        bool _chargePrepaidFee;
        uint256 _remainingLoan;
        uint256 _nextPhrasePenalty;
        uint256 _nextPhraseInterest;
        uint256 _dueDateTimestamp;

        // Check if number of requests is 0 => create new requests, if not then update current request as LATE or COMPLETE and create new requests
        IPawnNFTBase.NFTPaymentRequest[]
            storage requests = contractPaymentRequestMapping[contractId];
        if (requests.length > 0) {
            // not first phrase, get previous request
            IPawnNFTBase.NFTPaymentRequest storage previousRequest = requests[
                requests.length - 1
            ];

            // Validate: time must over due date of current payment
            require(block.timestamp >= previousRequest.dueDateTimestamp, "0");

            // Validate: remaining loan must valid
            // require(previousRequest.remainingLoan == _remainingLoan, "1");
            _remainingLoan = previousRequest.remainingLoan;

            (, , uint256 penaltyRate, , ) = HubInterface(contractHub)
                .getPawnNFTConfig();
            _nextPhrasePenalty = IExchange(getExchange()).calculatePenalty_NFT(
                previousRequest,
                currentContract,
                penaltyRate
            );

            uint256 _timeStamp;
            if (paymentRequestType == IEnums.PaymentRequestTypeEnum.INTEREST) {
                _timeStamp = PawnNFTLib.calculatedueDateTimestampInterest(
                    currentContract.terms.repaymentCycleType
                );

                _nextPhraseInterest = IExchange(getExchange())
                    .calculateInterest_NFT(_remainingLoan, currentContract);
            }
            if (paymentRequestType == IEnums.PaymentRequestTypeEnum.OVERDUE) {
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
            // require(
            //     _dueDateTimestamp <= currentContract.terms.contractEndDate,
            //     "2"
            // );
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
                previousRequest.status = IEnums.PaymentRequestStatusEnum.LATE;
                // Update late counter of contract
                currentContract.lateCount += 1;

                // Adjust reputation score
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
                    emit PaymentRequestEvent(-1, contractId, previousRequest);

                    _liquidationExecution(
                        contractId,
                        IEnums.ContractLiquidedReasonType.LATE
                    );
                    return;
                }
            } else {
                previousRequest.status = IEnums
                    .PaymentRequestStatusEnum
                    .COMPLETE;

                // Adjust reputation score
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
                        contractId,
                        IEnums.ContractLiquidedReasonType.UNPAID
                    );
                    return;
                } else {
                    // paid full => release collateral
                    _returnCollateralToBorrowerAndCloseContract(contractId);
                    return;
                }
            }

            emit PaymentRequestEvent(-1, contractId, previousRequest);
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
                _returnCollateralToBorrowerAndCloseContract(contractId);
                return;
            }
        }

        // Create new payment request and store to contract
        IPawnNFTBase.NFTPaymentRequest memory newRequest = IPawnNFTBase
            .NFTPaymentRequest({
                requestId: requests.length,
                paymentRequestType: paymentRequestType,
                remainingLoan: _remainingLoan,
                penalty: _nextPhrasePenalty,
                interest: _nextPhraseInterest,
                remainingPenalty: _nextPhrasePenalty,
                remainingInterest: _nextPhraseInterest,
                dueDateTimestamp: _dueDateTimestamp,
                status: IEnums.PaymentRequestStatusEnum.ACTIVE,
                chargePrepaidFee: _chargePrepaidFee
            });
        requests.push(newRequest);
        emit PaymentRequestEvent(paymentRequestId, contractId, newRequest);
    }

    /**
     * @dev get Contract must active
     * @param  contractId is id of contract
     */
    function contractMustActive(uint256 contractId)
        internal
        view
        returns (IPawnNFTBase.NFTLoanContract storage loanContract)
    {
        // Validate: Contract must active
        loanContract = contracts[contractId];
        require(loanContract.status == IEnums.ContractStatus.ACTIVE, "0");
    }

    /**
     * @dev Perform contract liquidation
     * @param  contractId is id of contract
     * @param  reasonType is type of reason for liquidation of the contract
     */
    function _liquidationExecution(
        uint256 contractId,
        IEnums.ContractLiquidedReasonType reasonType
    ) internal {
        IPawnNFTBase.NFTLoanContract storage loanContract = contracts[
            contractId
        ];

        // Execute: update status of contract to DEFAULT, collateral to COMPLETE
        loanContract.status = IEnums.ContractStatus.DEFAULT;
        IPawnNFTBase.NFTPaymentRequest[]
            storage _paymentRequests = contractPaymentRequestMapping[
                contractId
            ];

        if (reasonType != IEnums.ContractLiquidedReasonType.LATE) {
            IPawnNFTBase.NFTPaymentRequest
                storage _lastPaymentRequest = _paymentRequests[
                    _paymentRequests.length - 1
                ];
            _lastPaymentRequest.status = IEnums
                .PaymentRequestStatusEnum
                .DEFAULT;
        }

        // IPawnNFTBase.NFTCollateral storage _collateral = collaterals[
        //     loanContract.nftCollateralId
        // ];

        IPawnNFT(getPawnNFTContract()).updateCollateralStatus(
            loanContract.nftCollateralId,
            IEnums.CollateralStatus.COMPLETED
        );

        IPawnNFTBase.NFTContractLiquidationData memory liquidationData;

        {
            // (address token, , , ) = IDFYHardEvaluation(getEvaluation())
            //     .getEvaluationWithTokenId(
            //         _collateral.nftContract,
            //         _collateral.nftTokenId
            //     );

            (address token, uint256 price, ) = IPawnNFT(getPawnNFTContract())
                .getInformationNFT(
                    loanContract.terms.nftCollateralAsset,
                    loanContract.terms.nftTokenId
                );

            (
                uint256 _tokenEvaluationRate,
                uint256 _loanExchangeRate,
                uint256 _repaymentExchangeRate,
                uint256 _rateUpdateTime
            ) = IExchange(getExchange()).RateAndTimestamp_NFT(
                    loanContract,
                    token
                );

            // Emit Event ContractLiquidedEvent
            liquidationData = IPawnNFTBase.NFTContractLiquidationData(
                contractId,
                _tokenEvaluationRate,
                _loanExchangeRate,
                _repaymentExchangeRate,
                _rateUpdateTime,
                reasonType
            );
        }

        emit ContractLiquidedEvent(liquidationData);

        CollectionStandard _collectionStandard = CommonLib.verifyTokenInfo(
            loanContract.terms.nftCollateralAsset,
            loanContract.terms.nftTokenId,
            loanContract.terms.nftCollateralAmount,
            loanContract.terms.borrower
        );
        PawnNFTLib.safeTranferNFTToken(
            loanContract.terms.nftCollateralAsset,
            address(this),
            loanContract.terms.lender,
            loanContract.terms.nftTokenId,
            loanContract.terms.nftCollateralAmount,
            _collectionStandard
        );

        // Adjust reputation score
        IReputation(getReputation()).adjustReputationScore(
            loanContract.terms.borrower,
            IReputation.ReasonType.BR_LATE_PAYMENT
        );

        IReputation(getReputation()).adjustReputationScore(
            loanContract.terms.borrower,
            IReputation.ReasonType.BR_CONTRACT_DEFAULTED
        );
    }

    /**
     * @dev return collateral to borrower and close contract
     * @param  contractId is id of contract
     */
    function _returnCollateralToBorrowerAndCloseContract(uint256 contractId)
        internal
    {
        IPawnNFTBase.NFTLoanContract storage loanContract = contracts[
            contractId
        ];

        // Execute: Update status of contract to COMPLETE, collateral to COMPLETE
        loanContract.status = IEnums.ContractStatus.COMPLETED;
        IPawnNFTBase.NFTPaymentRequest[]
            storage _paymentRequests = contractPaymentRequestMapping[
                contractId
            ];
        IPawnNFTBase.NFTPaymentRequest
            storage _lastPaymentRequest = _paymentRequests[
                _paymentRequests.length - 1
            ];
        _lastPaymentRequest.status = IEnums.PaymentRequestStatusEnum.COMPLETE;

        // IPawnNFTBase.NFTCollateral storage _collateral = collaterals[
        //     loanContract.nftCollateralId
        // ];

        IPawnNFT(getPawnNFTContract()).updateCollateralStatus(
            loanContract.nftCollateralId,
            IEnums.CollateralStatus.COMPLETED
        );

        // Emit Event ContractLiquidedEvent
        emit LoanContractCompletedEvent(contractId);
        emit PaymentRequestEvent(-1, contractId, _lastPaymentRequest);

        // Execute: Transfer collateral to borrower
        // (
        //     ,
        //     ,
        //     ,
        //     IDFYHardEvaluation.CollectionStandard _collectionStandard
        // ) = IDFYHardEvaluation(getEvaluation()).getEvaluationWithTokenId(
        //         _collateral.nftContract,
        //         _collateral.nftTokenId
        //     );
        CollectionStandard _collectionStandard = CommonLib.verifyTokenInfo(
            loanContract.terms.nftCollateralAsset,
            loanContract.terms.nftTokenId,
            loanContract.terms.nftCollateralAmount,
            loanContract.terms.borrower
        );
        PawnNFTLib.safeTranferNFTToken(
            loanContract.terms.nftCollateralAsset,
            address(this),
            loanContract.terms.borrower,
            loanContract.terms.nftTokenId,
            loanContract.terms.nftCollateralAmount,
            _collectionStandard
        );

        // Adjust reputation score
        IReputation(getReputation()).adjustReputationScore(
            loanContract.terms.borrower,
            IReputation.ReasonType.BR_ONTIME_PAYMENT
        );

        IReputation(getReputation()).adjustReputationScore(
            loanContract.terms.borrower,
            IReputation.ReasonType.BR_CONTRACT_COMPLETE
        );
    }

    /**
     * @dev the borrower repays the debt
     * @param  contractId is id of contract
     * @param  paidPenaltyAmount is paid penalty amount
     * @param  paidInterestAmount is paid interest amount
     * @param  paidLoanAmount is paid loan amount
     */
    function repayment(
        uint256 contractId,
        uint256 paidPenaltyAmount,
        uint256 paidInterestAmount,
        uint256 paidLoanAmount
    ) external whenNotPaused {
        // Get contract & payment request
        IPawnNFTBase.NFTLoanContract storage loanContract = contractMustActive(
            contractId
        );
        IPawnNFTBase.NFTPaymentRequest[]
            storage requests = contractPaymentRequestMapping[contractId];
        require(requests.length > 0, "0");
        IPawnNFTBase.NFTPaymentRequest storage _paymentRequest = requests[
            requests.length - 1
        ];

        // Validation: Contract must not overdue
        require(block.timestamp <= loanContract.terms.contractEndDate, "1");

        // Validation: current payment request must active and not over due
        require(
            _paymentRequest.status == IEnums.PaymentRequestStatusEnum.ACTIVE,
            "2"
        );
        if (paidPenaltyAmount + paidInterestAmount > 0) {
            require(block.timestamp <= _paymentRequest.dueDateTimestamp, "3");
        }

        // Calculate paid amount / remaining amount, if greater => get paid amount
        if (paidPenaltyAmount > _paymentRequest.remainingPenalty) {
            paidPenaltyAmount = _paymentRequest.remainingPenalty;
        }

        if (paidInterestAmount > _paymentRequest.remainingInterest) {
            paidInterestAmount = _paymentRequest.remainingInterest;
        }

        if (paidLoanAmount > _paymentRequest.remainingLoan) {
            paidLoanAmount = _paymentRequest.remainingLoan;
        }

        // Calculate fee amount based on paid amount

        (uint256 ZOOM, , , , ) = HubInterface(contractHub).getPawnNFTConfig();
        uint256 _feePenalty = CommonLib.calculateSystemFee(
            paidPenaltyAmount,
            loanContract.terms.systemFeeRate,
            ZOOM
        );
        uint256 _feeInterest = CommonLib.calculateSystemFee(
            paidInterestAmount,
            loanContract.terms.systemFeeRate,
            ZOOM
        );

        uint256 _prepaidFee = 0;
        if (_paymentRequest.chargePrepaidFee) {
            _prepaidFee = CommonLib.calculateSystemFee(
                paidLoanAmount,
                loanContract.terms.prepaidFeeRate,
                ZOOM
            );
        }

        // Update paid amount on payment request
        _paymentRequest.remainingPenalty -= paidPenaltyAmount;
        _paymentRequest.remainingInterest -= paidInterestAmount;
        _paymentRequest.remainingLoan -= paidLoanAmount;

        // emit event repayment
        IPawnNFTBase.NFTRepaymentEventData memory repaymentData = IPawnNFTBase
            .NFTRepaymentEventData(
                contractId,
                paidPenaltyAmount,
                paidInterestAmount,
                paidLoanAmount,
                _feePenalty,
                _feeInterest,
                _prepaidFee,
                _paymentRequest.requestId
            );
        emit RepaymentEvent(repaymentData);

        // If remaining loan = 0 => paidoff => execute release collateral
        if (
            _paymentRequest.remainingLoan == 0 &&
            _paymentRequest.remainingPenalty == 0 &&
            _paymentRequest.remainingInterest == 0
        ) _returnCollateralToBorrowerAndCloseContract(contractId);

        uint256 _totalFee;
        uint256 _totalTransferAmount;
        uint256 _total = paidPenaltyAmount + paidInterestAmount;
        (address feeWallet, ) = HubInterface(contractHub).getSystemConfig();
        {
            if (_total > 0) {
                // Transfer fee to fee wallet
                _totalFee = _feePenalty + _feeInterest;
                CommonLib.safeTransfer(
                    loanContract.terms.repaymentAsset,
                    msg.sender,
                    feeWallet,
                    _totalFee
                );

                // Transfer penalty and interest to lender except fee amount
                _totalTransferAmount = _total - _feePenalty - _feeInterest;
                CommonLib.safeTransfer(
                    loanContract.terms.repaymentAsset,
                    msg.sender,
                    loanContract.terms.lender,
                    _totalTransferAmount
                );
            }
        }
        {
            if (paidLoanAmount > 0) {
                // Transfer loan amount and prepaid fee to lender
                _totalTransferAmount = paidLoanAmount + _prepaidFee;
                CommonLib.safeTransfer(
                    loanContract.terms.loanAsset,
                    msg.sender,
                    loanContract.terms.lender,
                    _totalTransferAmount
                );
            }
        }
    }

    function collateralRiskLiquidationExecution(uint256 contractId)
        external
        whenNotPaused
        onlyOperator
    {
        // // Validate: Contract must active
        // IPawnNFTBase.NFTLoanContract storage loanContract = contractMustActive(
        //     contractId
        // );
        // // IPawnNFTBase.NFTCollateral storage _collateral = collaterals[
        // //     loanContract.nftCollateralId
        // // ];
        // // get Evaluation from address of EvaluationContract
        // // (address token, uint256 price, , ) = IDFYHardEvaluation(getEvaluation())
        // //     .getEvaluationWithTokenId(
        // //         _collateral.nftContract,
        // //         _collateral.nftTokenId
        // //     );
        // (address token, uint256 price, ) = IPawnNFT(getPawnNFTContract())
        //     .getInformationNFT(
        //         loanContract.terms.nftCollateralAsset,
        //         loanContract.terms.nftTokenId
        //     );
        // (
        //     uint256 remainingRepayment,
        //     uint256 remainingLoan
        // ) = _calculateRemainingLoanAndRepaymentFromContract(
        //         contractId,
        //         loanContract
        //     );
        // (
        //     uint256 _collateralPerRepaymentTokenExchangeRate,
        //     uint256 _collateralPerLoanAssetExchangeRate
        // ) = IExchange(getExchange())
        //         .collateralPerRepaymentAndLoanTokenExchangeRate_NFT(
        //             loanContract,
        //             token
        //         );
        // {
        //     (uint256 ZOOM, , , , ) = HubInterface(contractHub)
        //         .getPawnNFTConfig();
        //     uint256 valueOfRemainingRepayment = (_collateralPerRepaymentTokenExchangeRate *
        //             remainingRepayment) / (ZOOM * 10**5);
        //     uint256 valueOfRemainingLoan = (_collateralPerLoanAssetExchangeRate *
        //             remainingLoan) / (ZOOM * 10**5);
        //     uint256 valueOfCollateralLiquidationThreshold = (price *
        //         loanContract.terms.liquidityThreshold) / (100 * ZOOM);
        //     uint256 total = valueOfRemainingLoan + valueOfRemainingRepayment;
        //     bool valid = total > valueOfCollateralLiquidationThreshold;
        //     require(valid, "0");
        // }
        // // Execute: call internal liquidation
        // _liquidationExecution(
        //     contractId,
        //     IEnums.ContractLiquidedReasonType.RISK
        // );
    }

    /**
     * @dev liquidate the contract if the borrower has not paid in full at the end of the contract
     * @param contractId is id of contract
     */
    function lateLiquidationExecution(uint256 contractId)
        external
        whenNotPaused
    {
        // Validate: Contract must active
        IPawnNFTBase.NFTLoanContract storage loanContract = contractMustActive(
            contractId
        );

        // validate: contract have lateCount == lateThreshold
        require(
            loanContract.lateCount >= loanContract.terms.lateThreshold,
            "0"
        );

        // Execute: call internal liquidation
        _liquidationExecution(
            contractId,
            IEnums.ContractLiquidedReasonType.LATE
        );
    }

    /**
     * @dev liquidate the contract if the borrower has not paid in full at the end of the contract
     * @param contractId is id of contract
     */
    function notPaidFullAtEndContractLiquidation(uint256 contractId)
        external
        whenNotPaused
    {
        IPawnNFTBase.NFTLoanContract storage loanContract = contractMustActive(
            contractId
        );
        // validate: current is over contract end date
        require(block.timestamp >= loanContract.terms.contractEndDate, "0");

        // validate: remaining loan, interest, penalty haven't paid in full
        (
            uint256 remainingRepayment,
            uint256 remainingLoan
        ) = _calculateRemainingLoanAndRepaymentFromContract(
                contractId,
                loanContract
            );

        require(remainingRepayment + remainingLoan > 0, "1");

        // Execute: call internal liquidation
        _liquidationExecution(
            contractId,
            IEnums.ContractLiquidedReasonType.UNPAID
        );
    }

    function _calculateRemainingLoanAndRepaymentFromContract(
        uint256 contractId,
        IPawnNFTBase.NFTLoanContract storage loanContract
    )
        internal
        view
        returns (uint256 remainingRepayment, uint256 remainingLoan)
    {
        // Validate: sum of unpaid interest, penalty and remaining loan in value must reach liquidation threshold of collateral value
        IPawnNFTBase.NFTPaymentRequest[]
            storage requests = contractPaymentRequestMapping[contractId];
        if (requests.length > 0) {
            // Have payment request
            IPawnNFTBase.NFTPaymentRequest storage _paymentRequest = requests[
                requests.length - 1
            ];
            remainingRepayment =
                _paymentRequest.remainingInterest +
                _paymentRequest.remainingPenalty;
            remainingLoan = _paymentRequest.remainingLoan;
        } else {
            // Haven't had payment request
            remainingRepayment = 0;
            remainingLoan = loanContract.terms.loanAmount;
        }
    }

    /**========================= */

    function getPawnNFTContract() internal view returns (address pawnAddress) {
        (pawnAddress, ) = HubInterface(contractHub).getContractAddress(
            type(IPawnNFT).interfaceId
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
            IEnums.ContractStatus status
        )
    {
        IPawnNFTBase.NFTLoanContract storage loanContract = contracts[
            contractId
        ];
        borrower = loanContract.terms.borrower;
        lender = loanContract.terms.lender;
        status = loanContract.status;
    }
}
