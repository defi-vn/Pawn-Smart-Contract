// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "./PawnNFTModel.sol";
import "./PawnNFTLib.sol";
import "./IPawnNFT.sol";
import "./ILoanNFT.sol";

// import "../reputation/IReputation.sol";
// import "./IPawnNFT.sol";
// import "../exchange/Exchange_NFT.sol";

contract PawnNFTContract is PawnNFTModel, IPawnNFT {
    using AddressUpgradeable for address;
    using SafeMathUpgradeable for uint256;
    using CountersUpgradeable for CountersUpgradeable.Counter;
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using CollateralLib_NFT for IPawnNFTBase.NFTCollateral;
    using OfferLib_NFT for IPawnNFTBase.NFTOffer;
    /** ======================================= EVENT ================================== */

    event CollateralEvent_NFT(
        uint256 nftCollateralId,
        IPawnNFTBase.NFTCollateral data,
        uint256 UID
    );

    //create offer & cancel
    event OfferEvent_NFT(
        uint256 offerId,
        uint256 nftCollateralId,
        IPawnNFTBase.NFTOffer data,
        uint256 UID
    );

    //accept offer
    event LoanContractCreatedEvent_NFT(
        address fromAddress,
        uint256 contractId,
        IPawnNFTBase.NFTLoanContract data,
        uint256 UID
    );

    //repayment
    event PaymentRequestEvent_NFT(
        uint256 contractId,
        IPawnNFTBase.NFTPaymentRequest data
    );

    event RepaymentEvent_NFT(
        uint256 contractId,
        uint256 paidPenaltyAmount,
        uint256 paidInterestAmount,
        uint256 paidLoanAmount,
        uint256 paidPenaltyFeeAmount,
        uint256 paidInterestFeeAmount,
        uint256 prepaidAmount,
        uint256 UID
    );

    //liquidity & defaul
    event ContractLiquidedEvent_NFT(
        uint256 contractId,
        uint256 liquidedAmount,
        uint256 feeAmount,
        IEnums.ContractLiquidedReasonType reasonType
    );

    event LoanContractCompletedEvent_NFT(uint256 contractId);

    event CancelOfferEvent_NFT(
        uint256 offerId,
        uint256 nftCollateralId,
        address offerOwner,
        uint256 UID
    );

    address abc;

    // Total collateral
    CountersUpgradeable.Counter public numberCollaterals;

    // Mapping collateralId => Collateral
    mapping(uint256 => IPawnNFTBase.NFTCollateral) public collaterals;

    // Total offer
    CountersUpgradeable.Counter public numberOffers;

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

    /**
     * @dev create collateral function, collateral will be stored in this contract
     * @param _nftContract is address NFT token collection
     * @param _nftTokenId is token id of NFT
     * @param _loanAmount is amount collateral
     * @param _loanAsset is address of loan token
     * @param _nftTokenQuantity is quantity NFT token
     * @param _expectedDurationQty is expected duration
     * @param _durationType is expected duration type
     * @param _UID is UID pass create collateral to event collateral
     */

    function createCollateral(
        address _nftContract,
        uint256 _nftTokenId,
        uint256 _loanAmount,
        address _loanAsset,
        uint256 _nftTokenQuantity,
        uint256 _expectedDurationQty,
        IEnums.LoanDurationType _durationType,
        uint256 _UID
    ) external whenNotPaused nonReentrant {
        /**
        TODO: Implementation

        Chú ý: Kiểm tra bên Physical NFT, so khớp số NFT quantity với _nftTokenQuantity
        Chỉ cho phép input <= amount của NFT
        */

        // Check white list nft contract

        // require(
        //     HubInterface(abc).PawnNFTConfig.whitelistedCollateral[
        //         _nftContract
        //     ] == 1,
        //     "0"
        // );

        require(
            HubInterface(contractHub).getWhitelistCollateral_NFT(
                _nftContract
            ) == 1,
            "0"
        );
        //   require(whitelistCollateral[_nftContract] == 1, "0");

        // Check loan amount
        require(_loanAmount > 0 && _expectedDurationQty > 0, "1");

        // Check loan asset
        require(_loanAsset != address(0), "2");

        // Create Collateral Id
        uint256 collateralId = numberCollaterals.current();

        (
            ,
            ,
            ,
            IDFY_Hard_Evaluation.CollectionStandard _collectionStandard
        ) = IDFY_Hard_Evaluation(getEvaluation()).getEvaluationWithTokenId(
                _nftContract,
                _nftTokenId
            );
        // Transfer token
        PawnNFTLib.safeTranferNFTToken(
            _nftContract,
            msg.sender,
            address(this),
            _nftTokenId,
            _nftTokenQuantity,
            _collectionStandard
        );

        // Create collateral
        IPawnNFTBase.NFTCollateral storage _collateral = collaterals[
            collateralId
        ];

        _collateral.create(
            _nftContract,
            _nftTokenId,
            _loanAmount,
            _loanAsset,
            _nftTokenQuantity,
            _expectedDurationQty,
            _durationType
        );

        // Update number colaterals
        numberCollaterals.increment();

        emit CollateralEvent_NFT(collateralId, collaterals[collateralId], _UID);

        // Adjust reputation score
        // reputation.adjustReputationScore(
        //     msg.sender,
        //     IReputation.ReasonType.BR_CREATE_COLLATERAL
        // );
        IReputation(getReputation()).adjustReputationScore(
            msg.sender,
            IReputation.ReasonType.BR_CREATE_COLLATERAL
        );
    }

    function withdrawCollateral(uint256 _nftCollateralId, uint256 _UID)
        external
        whenNotPaused
    {
        IPawnNFTBase.NFTCollateral storage _collateral = collaterals[
            _nftCollateralId
        ];

        // Check owner collateral
        require(
            _collateral.owner == msg.sender &&
                _collateral.status == IEnums.CollateralStatus.OPEN,
            "0"
        );

        (
            ,
            ,
            ,
            IDFY_Hard_Evaluation.CollectionStandard _collectionStandard
        ) = IDFY_Hard_Evaluation(getEvaluation()).getEvaluationWithTokenId(
                _collateral.nftContract,
                _collateral.nftTokenId
            );

        // Return NFT token to owner
        PawnNFTLib.safeTranferNFTToken(
            _collateral.nftContract,
            address(this),
            _collateral.owner,
            _collateral.nftTokenId,
            _collateral.nftTokenQuantity,
            _collectionStandard
        );

        // Remove relation of collateral and offers
        IPawnNFTBase.NFTCollateralOfferList
            storage collateralOfferList = collateralOffersMapping[
                _nftCollateralId
            ];
        if (collateralOfferList.isInit == true) {
            for (
                uint256 i = 0;
                i < collateralOfferList.offerIdList.length;
                i++
            ) {
                uint256 offerId = collateralOfferList.offerIdList[i];
                IPawnNFTBase.NFTOffer storage offer = collateralOfferList
                    .offerMapping[offerId];
                emit CancelOfferEvent_NFT(
                    offerId,
                    _nftCollateralId,
                    offer.owner,
                    _UID
                );
            }
            delete collateralOffersMapping[_nftCollateralId];
        }

        // Update collateral status
        _collateral.status = IEnums.CollateralStatus.CANCEL;

        emit CollateralEvent_NFT(_nftCollateralId, _collateral, _UID);

        delete collaterals[_nftCollateralId];

        // Adjust reputation score
        // reputation.adjustReputationScore(
        //     msg.sender,
        //     IReputation.ReasonType.BR_CANCEL_COLLATERAL
        // );
        IReputation(getReputation()).adjustReputationScore(
            msg.sender,
            IReputation.ReasonType.BR_CANCEL_COLLATERAL
        );
    }

    /**
     * @dev create offer to collateral
     * @param _nftCollateralId is id collateral
     * @param _repaymentAsset is address token repayment
     * @param _loanToValue is LTV token of loan
     * @param _loanAmount is amount token of loan
     * @param _interest is interest of loan
     * @param _duration is duration of loan
     * @param _liquidityThreshold is liquidity threshold of loan
     * @param _loanDurationType is duration type of loan
     * @param _repaymentCycleType is repayment type of loan
     */
    function createOffer(
        uint256 _nftCollateralId,
        address _repaymentAsset,
        uint256 _loanToValue,
        uint256 _loanAmount,
        uint256 _interest,
        uint256 _duration,
        uint256 _liquidityThreshold,
        IEnums.LoanDurationType _loanDurationType,
        IEnums.LoanDurationType _repaymentCycleType,
        uint256 _UID
    ) external whenNotPaused {
        // Get collateral
        IPawnNFTBase.NFTCollateral storage _collateral = collaterals[
            _nftCollateralId
        ];

        // Check owner collateral
        require(
            _collateral.owner != msg.sender &&
                _collateral.status == IEnums.CollateralStatus.OPEN,
            "0"
        ); // You can not offer.

        // Check approve
        require(
            IERC20Upgradeable(_collateral.loanAsset).allowance(
                msg.sender,
                address(this)
            ) >= _loanAmount,
            "1"
        ); // You not approve.

        // Check repayment asset
        require(_repaymentAsset != address(0), "2"); // Address repayment asset must be different address(0).

        // Check loan amount
        require(
            _loanToValue > 0 &&
                _loanAmount > 0 &&
                _interest > 0 &&
                _liquidityThreshold > _loanToValue,
            "3"
        ); // Loan to value must be grean that 0.

        // Gennerate Offer Id
        uint256 offerId = numberOffers.current();

        // Get offers of collateral
        IPawnNFTBase.NFTCollateralOfferList
            storage _collateralOfferList = collateralOffersMapping[
                _nftCollateralId
            ];

        if (!_collateralOfferList.isInit) {
            _collateralOfferList.isInit = true;
        }

        IPawnNFTBase.NFTOffer storage _offer = _collateralOfferList
            .offerMapping[offerId];

        _offer.create(
            _repaymentAsset,
            _loanToValue,
            _loanAmount,
            _interest,
            _duration,
            _liquidityThreshold,
            _loanDurationType,
            _repaymentCycleType
        );

        _collateralOfferList.offerIdList.push(offerId);

        _collateralOfferList.isInit = true;

        // Update number offer
        numberOffers.increment();

        emit OfferEvent_NFT(
            offerId,
            _nftCollateralId,
            _collateralOfferList.offerMapping[offerId],
            _UID
        );

        // Adjust reputation score
        // reputation.adjustReputationScore(
        //     msg.sender,
        //     IReputation.ReasonType.LD_CREATE_OFFER
        // );

        IReputation(getReputation()).adjustReputationScore(
            msg.sender,
            IReputation.ReasonType.LD_CREATE_OFFER
        );
    }

    function cancelOffer(
        uint256 _offerId,
        uint256 _nftCollateralId,
        uint256 _UID
    ) external whenNotPaused {
        // Get offer
        IPawnNFTBase.NFTCollateralOfferList
            storage _collateralOfferList = collateralOffersMapping[
                _nftCollateralId
            ];

        // Check Offer Collater isnit
        require(_collateralOfferList.isInit == true, "0");

        // Get offer
        IPawnNFTBase.NFTOffer storage _offer = _collateralOfferList
            .offerMapping[_offerId];

        address offerOwner = _offer.owner;

        _offer.cancel(
            _offerId,
            collaterals[_nftCollateralId].owner,
            _collateralOfferList
        );

        //reject Offer
        if (msg.sender == collaterals[_nftCollateralId].owner) {
            emit CancelOfferEvent_NFT(
                _offerId,
                _nftCollateralId,
                offerOwner,
                _UID
            );
        }

        // cancel offer
        if (msg.sender == offerOwner) {
            emit CancelOfferEvent_NFT(
                _offerId,
                _nftCollateralId,
                msg.sender,
                _UID
            );

            // Adjust reputation score
            // reputation.adjustReputationScore(
            //     msg.sender,
            //     IReputation.ReasonType.LD_CANCEL_OFFER
            // );
            IReputation(getReputation()).adjustReputationScore(
                msg.sender,
                IReputation.ReasonType.LD_CANCEL_OFFER
            );
        }
    }

    function acceptOffer(
        uint256 _nftCollateralId,
        uint256 _offerId,
        uint256 _UID
    ) external whenNotPaused {
        IPawnNFTBase.NFTCollateral storage collateral = collaterals[
            _nftCollateralId
        ];
        // Check owner of collateral
        require(msg.sender == collateral.owner, "0");
        // Check for collateralNFT status is OPEN
        require(collateral.status == IEnums.CollateralStatus.OPEN, "1");

        IPawnNFTBase.NFTCollateralOfferList
            storage collateralOfferList = collateralOffersMapping[
                _nftCollateralId
            ];
        require(collateralOfferList.isInit == true, "2");
        // Check for offer status is PENDING
        IPawnNFTBase.NFTOffer storage offer = collateralOfferList.offerMapping[
            _offerId
        ];

        require(offer.status == IEnums.OfferStatus.PENDING, "3");

        // uint256 exchangeRate = exchange.exchangeRateOfIPawnNFTBase.NFTOffer(
        //     collateral.loanAsset,
        //     offer.repaymentAsset
        // );
        uint256 exchangeRate = IExchange(getExchange()).exchangeRateOfOffer_NFT(
            collateral.loanAsset,
            offer.repaymentAsset
        );

        IPawnNFTBase.NFTContractRawData memory contractData = IPawnNFTBase
            .NFTContractRawData(
                _nftCollateralId,
                collateral,
                _offerId,
                offer.loanAmount,
                offer.owner,
                offer.repaymentAsset,
                offer.interest,
                offer.loanDurationType,
                offer.liquidityThreshold,
                exchangeRate
            );

        //   LoanIPawnNFTBase.NFTLoanContract.createContract(contractData, _UID);
        ILoanNFT(getLoanContractNFT()).createContract(contractData, _UID);

        // Change status of offer and collateral
        offer.status = IEnums.OfferStatus.ACCEPTED;
        collateral.status = IEnums.CollateralStatus.DOING;

        // Cancel other offer sent to this collateral
        for (uint256 i = 0; i < collateralOfferList.offerIdList.length; i++) {
            uint256 thisOfferId = collateralOfferList.offerIdList[i];
            if (thisOfferId != _offerId) {
                //Offer storage thisOffer = collateralOfferList.offerMapping[thisOfferId];
                emit CancelOfferEvent_NFT(
                    thisOfferId,
                    _nftCollateralId,
                    offer.owner,
                    _UID
                );
                delete collateralOfferList.offerMapping[thisOfferId];
            }
        }
        delete collateralOfferList.offerIdList;
        collateralOfferList.offerIdList.push(_offerId);

        // Transfer loan asset to collateral owner
        CommonLib.safeTransfer(
            collateral.loanAsset,
            offer.owner,
            collateral.owner,
            offer.loanAmount
        );

        (
            ,
            ,
            ,
            IDFY_Hard_Evaluation.CollectionStandard _collectionStandard
        ) = IDFY_Hard_Evaluation(getEvaluation()).getEvaluationWithTokenId(
                collateral.nftContract,
                collateral.nftTokenId
            );
        PawnNFTLib.safeTranferNFTToken(
            collateral.nftContract,
            address(this),
            address(getLoanContractNFT()),
            collateral.nftTokenId,
            collateral.nftTokenQuantity,
            _collectionStandard
        );

        // Adjust reputation score
        // reputation.adjustReputationScore(
        //     msg.sender,
        //     IReputation.ReasonType.BR_ACCEPT_OFFER
        // );
        // reputation.adjustReputationScore(
        //     offer.owner,
        //     IReputation.ReasonType.LD_ACCEPT_OFFER
        // );

        IReputation(getReputation()).adjustReputationScore(
            msg.sender,
            IReputation.ReasonType.BR_ACCEPT_OFFER
        );

        IReputation(getReputation()).adjustReputationScore(
            offer.owner,
            IReputation.ReasonType.LD_ACCEPT_OFFER
        );
    }

    function _validateCollateral(uint256 _collateralId)
        private
        view
        returns (IPawnNFTBase.NFTCollateral storage collateral)
    {
        collateral = collaterals[_collateralId];
        require(collateral.status == IEnums.CollateralStatus.DOING, "1"); // invalid collateral
    }

    function updateCollateralStatus(
        uint256 _collateralId,
        IEnums.CollateralStatus _status
    ) external override whenNotPaused {
        _isValidCaller();
        IPawnNFTBase.NFTCollateral storage collateral = _validateCollateral(
            _collateralId
        );

        collateral.status = _status;
    }

    function _isValidCaller() private view {
        require(
            msg.sender == getLoanContractNFT() ||
                IAccessControlUpgradeable(contractHub).hasRole(
                    HubRoles.OPERATOR_ROLE,
                    msg.sender
                ) ||
                IAccessControlUpgradeable(contractHub).hasRole(
                    HubRoles.DEFAULT_ADMIN_ROLE,
                    msg.sender
                ),
            "0"
        ); // caller not allowed
    }

    /** ================================ ACCEPT OFFER ============================= */
    /**
 

    /** ==================== Loan Contract functions & states ==================== */
    // IPawnNFT public LoanIPawnNFTBase.NFTLoanContract;

    // function setPawnLoanContract(address _pawnLoanAddress)
    //     external
    //     onlyRole(DEFAULT_ADMIN_ROLE)
    // {
    //     LoanIPawnNFTBase.NFTLoanContract = IPawnNFT(_pawnLoanAddress);
    // }
    /** ==== Reputation =======*/

    function signature() public pure override returns (bytes4) {
        return type(ILoanNFT).interfaceId;
    }

    /**============get Loan Contract ================ */

    function getLoanContractNFT()
        internal
        view
        returns (address _LoanContractAddress)
    {
        (_LoanContractAddress, ) = HubInterface(contractHub).getContractAddress(
            type(IPawnNFT).interfaceId
        );
    }
}
