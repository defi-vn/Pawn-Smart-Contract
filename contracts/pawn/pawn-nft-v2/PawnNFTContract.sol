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

    // Total collateral
    CountersUpgradeable.Counter public numberCollaterals;

    // Total offer
    CountersUpgradeable.Counter public numberOffers;

    // Mapping collateralId => Collateral
    mapping(uint256 => IPawnNFTBase.NFTCollateral) public collaterals;

    // Mapping collateralId => list offer of collateral
    mapping(uint256 => IPawnNFTBase.NFTCollateralOfferList)
        public collateralOffersMapping;

    /** ==================== Standard interface function implementations ==================== */

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(PawnNFTModel, IERC165Upgradeable)
        returns (bool)
    {
        return
            interfaceId == type(IPawnNFT).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function signature() external pure override returns (bytes4) {
        return type(IPawnNFT).interfaceId;
    }

    /** ==================== NFT Collateral related operations ==================== */

    /**
     * @dev create collateral function, collateral will be stored in this contract
     * @param nftContract is address NFT token collection
     * @param nftTokenId is token id of NFT
     * @param loanAmount is amount collateral
     * @param loanAsset is address of loan token
     * @param nftTokenQuantity is quantity NFT token
     * @param expectedDurationQty is expected duration
     * @param durationType is expected duration type
     * @param _UID is UID pass create collateral to event collateral
     */
    function createCollateral(
        address nftContract,
        uint256 nftTokenId,
        uint256 loanAmount,
        address loanAsset,
        uint256 nftTokenQuantity,
        uint256 expectedDurationQty,
        IEnums.LoanDurationType durationType,
        uint256 _UID
    ) external whenContractNotPaused nonReentrant {
        /**
        TODO: Implementation

        Chú ý: Kiểm tra bên Physical NFT, so khớp số NFT quantity với nftTokenQuantity
        Chỉ cho phép input <= amount của NFT
        */

        // Check white list nft contract

        // require(
        //     HubInterface(abc).PawnNFTConfig.whitelistedCollateral[
        //         nftContract
        //     ] == 1,
        //     "0"
        // );

        require(
            HubInterface(contractHub).getWhitelistCollateral_NFT(nftContract) ==
                1,
            "0"
        );
        //   require(whitelistCollateral[nftContract] == 1, "0");

        // Check loan amount
        require(loanAmount > 0 && expectedDurationQty > 0, "1");

        // Check loan asset
        require(loanAsset != address(0), "2");

        // Create Collateral Id
        uint256 collateralId = numberCollaterals.current();

        (
            ,
            ,
            ,
            IDFYHardEvaluation.CollectionStandard _collectionStandard
        ) = IDFYHardEvaluation(getEvaluation()).getEvaluationWithTokenId(
                nftContract,
                nftTokenId
            );

        // Transfer token
        PawnNFTLib.safeTranferNFTToken(
            nftContract,
            _msgSender(),
            address(this),
            nftTokenId,
            nftTokenQuantity,
            _collectionStandard
        );

        // Create collateral
        IPawnNFTBase.NFTCollateral storage _collateral = collaterals[
            collateralId
        ];

        _collateral.create(
            nftContract,
            nftTokenId,
            loanAmount,
            loanAsset,
            nftTokenQuantity,
            expectedDurationQty,
            durationType
        );

        // Update number colaterals
        numberCollaterals.increment();

        emit CollateralEvent_NFT(collateralId, collaterals[collateralId], _UID);

        // Adjust reputation score
        IReputation(getReputation()).adjustReputationScore(
            _msgSender(),
            IReputation.ReasonType.BR_CREATE_COLLATERAL
        );

        //  require(false, "after reputation");
    }

    function withdrawCollateral(uint256 nftCollateralId, uint256 _UID)
        external
        whenContractNotPaused
    {
        IPawnNFTBase.NFTCollateral storage _collateral = collaterals[
            nftCollateralId
        ];

        // Check owner collateral
        require(
            _collateral.owner == _msgSender() &&
                _collateral.status == IEnums.CollateralStatus.OPEN,
            "0"
        );

        (
            ,
            ,
            ,
            IDFYHardEvaluation.CollectionStandard _collectionStandard
        ) = IDFYHardEvaluation(getEvaluation()).getEvaluationWithTokenId(
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
                nftCollateralId
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
                    nftCollateralId,
                    offer.owner,
                    _UID
                );
            }
            delete collateralOffersMapping[nftCollateralId];
        }

        // Update collateral status
        _collateral.status = IEnums.CollateralStatus.CANCEL;

        emit CollateralEvent_NFT(nftCollateralId, _collateral, _UID);

        delete collaterals[nftCollateralId];

        // Adjust reputation score
        IReputation(getReputation()).adjustReputationScore(
            _msgSender(),
            IReputation.ReasonType.BR_CANCEL_COLLATERAL
        );
    }

    /**
     * @dev create offer to collateral
     * @param nftCollateralId is id collateral
     * @param repaymentAsset is address token repayment
     * @param loanToValue is LTV token of loan
     * @param loanAmount is amount token of loan
     * @param interest is interest of loan
     * @param duration is duration of loan
     * @param liquidityThreshold is liquidity threshold of loan
     * @param loanDurationType is duration type of loan
     * @param repaymentCycleType is repayment type of loan
     */
    function createOffer(
        uint256 nftCollateralId,
        address repaymentAsset,
        uint256 loanToValue,
        uint256 loanAmount,
        uint256 interest,
        uint256 duration,
        uint256 liquidityThreshold,
        IEnums.LoanDurationType loanDurationType,
        IEnums.LoanDurationType repaymentCycleType,
        uint256 _UID
    ) external whenContractNotPaused {
        // Get collateral
        IPawnNFTBase.NFTCollateral storage _collateral = collaterals[
            nftCollateralId
        ];

        // Check owner collateral
        require(
            _collateral.owner != _msgSender() &&
                _collateral.status == IEnums.CollateralStatus.OPEN,
            "0"
        ); // You can not offer.

        // Check approve
        require(
            IERC20Upgradeable(_collateral.loanAsset).allowance(
                _msgSender(),
                address(this)
            ) >= loanAmount,
            "1"
        ); // You not approve.

        // Check repayment asset
        require(repaymentAsset != address(0), "2"); // Address repayment asset must be different address(0).

        // Check loan amount
        require(
            loanToValue > 0 &&
                loanAmount > 0 &&
                interest > 0 &&
                liquidityThreshold > loanToValue,
            "3"
        ); // Loan to value must be grean that 0.

        // Gennerate Offer Id
        uint256 offerId = numberOffers.current();

        // Get offers of collateral
        IPawnNFTBase.NFTCollateralOfferList
            storage _collateralOfferList = collateralOffersMapping[
                nftCollateralId
            ];

        if (!_collateralOfferList.isInit) {
            _collateralOfferList.isInit = true;
        }

        IPawnNFTBase.NFTOffer storage _offer = _collateralOfferList
            .offerMapping[offerId];

        _offer.create(
            repaymentAsset,
            loanToValue,
            loanAmount,
            interest,
            duration,
            liquidityThreshold,
            loanDurationType,
            repaymentCycleType
        );

        _collateralOfferList.offerIdList.push(offerId);

        _collateralOfferList.isInit = true;

        // Update number offer
        numberOffers.increment();

        emit OfferEvent_NFT(
            offerId,
            nftCollateralId,
            _collateralOfferList.offerMapping[offerId],
            _UID
        );

        // Adjust reputation score
        IReputation(getReputation()).adjustReputationScore(
            _msgSender(),
            IReputation.ReasonType.LD_CREATE_OFFER
        );
    }

    function cancelOffer(
        uint256 offerId,
        uint256 nftCollateralId,
        uint256 _UID
    ) external whenContractNotPaused {
        // Get offer
        IPawnNFTBase.NFTCollateralOfferList
            storage _collateralOfferList = collateralOffersMapping[
                nftCollateralId
            ];

        // Check Offer Collater isnit
        require(_collateralOfferList.isInit == true, "0");

        // Get offer
        IPawnNFTBase.NFTOffer storage _offer = _collateralOfferList
            .offerMapping[offerId];

        address offerOwner = _offer.owner;

        _offer.cancel(
            offerId,
            collaterals[nftCollateralId].owner,
            _collateralOfferList
        );

        //reject Offer
        if (_msgSender() == collaterals[nftCollateralId].owner) {
            emit CancelOfferEvent_NFT(
                offerId,
                nftCollateralId,
                offerOwner,
                _UID
            );
        }

        // cancel offer
        if (_msgSender() == offerOwner) {
            emit CancelOfferEvent_NFT(
                offerId,
                nftCollateralId,
                _msgSender(),
                _UID
            );

            // Adjust reputation score
            IReputation(getReputation()).adjustReputationScore(
                _msgSender(),
                IReputation.ReasonType.LD_CANCEL_OFFER
            );
        }
    }

    function acceptOffer(
        uint256 nftCollateralId,
        uint256 offerId,
        uint256 _UID
    ) external whenContractNotPaused {
        IPawnNFTBase.NFTCollateral storage collateral = collaterals[
            nftCollateralId
        ];
        // Check owner of collateral
        require(_msgSender() == collateral.owner, "0");
        // Check for collateralNFT status is OPEN
        require(collateral.status == IEnums.CollateralStatus.OPEN, "1");

        IPawnNFTBase.NFTCollateralOfferList
            storage collateralOfferList = collateralOffersMapping[
                nftCollateralId
            ];
        require(collateralOfferList.isInit == true, "2");
        // Check for offer status is PENDING
        IPawnNFTBase.NFTOffer storage offer = collateralOfferList.offerMapping[
            offerId
        ];

        require(offer.status == IEnums.OfferStatus.PENDING, "3");

        // Get exchange rate of Offer
        uint256 exchangeRate = IExchange(getExchange()).exchangeRateOfOffer_NFT(
            collateral.loanAsset,
            offer.repaymentAsset
        );

        IPawnNFTBase.NFTContractRawData memory contractData = IPawnNFTBase
            .NFTContractRawData(
                nftCollateralId,
                collateral,
                offerId,
                offer.loanAmount,
                offer.owner,
                offer.repaymentAsset,
                offer.interest,
                offer.loanDurationType,
                offer.liquidityThreshold,
                exchangeRate,
                offer.duration
            );

        ILoanNFT(getLoanNFTContract()).createContract(contractData, _UID);

        // Change status of offer and collateral
        offer.status = IEnums.OfferStatus.ACCEPTED;
        collateral.status = IEnums.CollateralStatus.DOING;

        // Cancel other offer sent to this collateral
        for (uint256 i = 0; i < collateralOfferList.offerIdList.length; i++) {
            uint256 thisOfferId = collateralOfferList.offerIdList[i];
            if (thisOfferId != offerId) {
                //Offer storage thisOffer = collateralOfferList.offerMapping[thisOfferId];
                emit CancelOfferEvent_NFT(
                    thisOfferId,
                    nftCollateralId,
                    offer.owner,
                    _UID
                );
                delete collateralOfferList.offerMapping[thisOfferId];
            }
        }
        delete collateralOfferList.offerIdList;
        collateralOfferList.offerIdList.push(offerId);

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
            IDFYHardEvaluation.CollectionStandard _collectionStandard
        ) = IDFYHardEvaluation(getEvaluation()).getEvaluationWithTokenId(
                collateral.nftContract,
                collateral.nftTokenId
            );
        PawnNFTLib.safeTranferNFTToken(
            collateral.nftContract,
            address(this),
            address(getLoanNFTContract()),
            collateral.nftTokenId,
            collateral.nftTokenQuantity,
            _collectionStandard
        );

        // Adjust reputation score
        IReputation(getReputation()).adjustReputationScore(
            _msgSender(),
            IReputation.ReasonType.BR_ACCEPT_OFFER
        );

        IReputation(getReputation()).adjustReputationScore(
            offer.owner,
            IReputation.ReasonType.LD_ACCEPT_OFFER
        );
    }

    function _validateCollateral(uint256 collateralId)
        private
        view
        returns (IPawnNFTBase.NFTCollateral storage collateral)
    {
        collateral = collaterals[collateralId];
        require(collateral.status == IEnums.CollateralStatus.DOING, "1"); // invalid collateral
    }

    function updateCollateralStatus(
        uint256 collateralId,
        IEnums.CollateralStatus status
    ) external override whenContractNotPaused {
        _isValidCaller();
        IPawnNFTBase.NFTCollateral storage collateral = _validateCollateral(
            collateralId
        );

        collateral.status = status;
    }

    function _isValidCaller() private view {
        require(
            (_msgSender() == getLoanNFTContract() &&
                IAccessControlUpgradeable(contractHub).hasRole(
                    HubRoles.INTERNAL_CONTRACT,
                    _msgSender()
                )) ||
                IAccessControlUpgradeable(contractHub).hasRole(
                    HubRoles.OPERATOR_ROLE,
                    _msgSender()
                ),
            "Loan contract (internal) or Operator"
        ); // caller not allowed
    }

    /**============get Loan Contract ================ */

    function getLoanNFTContract()
        internal
        view
        returns (address loanContractAddress)
    {
        (loanContractAddress, ) = HubInterface(contractHub).getContractAddress(
            type(ILoanNFT).interfaceId
        );
    }
}
