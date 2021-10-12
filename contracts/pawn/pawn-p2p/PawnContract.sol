// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./PawnLib.sol";
import "../reputation/IReputation.sol";
import "../exchange/Exchange.sol";
import "../pawn-p2p-v2/PawnLoanContract.sol";

contract PawnContract is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using CollateralLib for Collateral;
    using OfferLib for Offer;
    using PawnPackageLib for PawnShopPackage;
    using LoanContractLib for Contract;

    mapping(address => uint256) public whitelistCollateral;
    address public operator; 
    address public feeWallet = address(this);
    uint256 public penaltyRate;
    uint256 public systemFeeRate; 
    uint256 public lateThreshold;
    uint256 public prepaidFeeRate;
    uint256 public ZOOM;  
    bool public initialized = false;
    address public admin;


    /**
     * @dev initialize function
     * @param _zoom is coefficient used to represent risk params
     */

    function initialize(
        uint256 _zoom
    ) external notInitialized {
        ZOOM = _zoom;
        initialized = true;
        admin = address(msg.sender);
    }

    function setOperator(address _newOperator) external onlyAdmin {
        operator = _newOperator;
    }

    function setFeeWallet(address _newFeeWallet) external onlyAdmin {
        feeWallet = _newFeeWallet;
    }

    function pause() external onlyAdmin {
        _pause();
    }

    function unPause() external onlyAdmin {
        _unpause();
    }

    /**
    * @dev set fee for each token
    * @param _feeRate is percentage of tokens to pay for the transaction
    */

    function setSystemFeeRate(uint256 _feeRate) external onlyAdmin {
        systemFeeRate = _feeRate;
    }

    /**
    * @dev set fee for each token
    * @param _feeRate is percentage of tokens to pay for the penalty
    */
    function setPenaltyRate(uint256 _feeRate) external onlyAdmin {
        penaltyRate = _feeRate;
    }

    /**
    * @dev set fee for each token
    * @param _threshold is number of time allowed for late repayment
    */
    function setLateThreshold(uint256 _threshold) external onlyAdmin {
        lateThreshold = _threshold;
    }

    function setPrepaidFeeRate(uint256 _feeRate) external onlyAdmin {
        prepaidFeeRate = _feeRate;
    }

    function setWhitelistCollateral(address _token, uint256 _status)
        external
        onlyAdmin
    {
        whitelistCollateral[_token] = _status;
    }

    modifier notInitialized() {
        require(!initialized, "-2");  //initialized
        _;
    }

    modifier isInitialized() {
        require(initialized, "-3");  //not-initialized
        _;
    }

    function _onlyOperator() private view {
        require(operator == msg.sender, "-0"); //operator
    }

    modifier onlyOperator() {
        // require(operator == msg.sender, "operator");
        _onlyOperator();
        _;
    }

    function _onlyAdmin() private view {
        require(admin == msg.sender, "-1");  //admin
    }

    modifier onlyAdmin() {
        // require(admin == msg.sender, "admin");
        _onlyAdmin();
        _;
    }

    function _whenNotPaused() private view {
        require(!paused(), "-4"); //Pausable: paused
    }
    
    modifier whenContractNotPaused() {
        // require(!paused(), "Pausable: paused");
        _whenNotPaused();
        _;
    }

    function emergencyWithdraw(address _token) external onlyAdmin whenPaused {
        PawnLib.safeTransfer(
            _token,
            address(this),
            admin,
            PawnLib.calculateAmount(_token, address(this))
        );
    }

    /** ========================= COLLATERAL FUNCTIONS & STATES ============================= */
    uint256 public numberCollaterals;
    mapping(uint256 => Collateral) public collaterals;
    
    event CreateCollateralEvent(
        uint256 collateralId,
        Collateral data
    );

    event WithdrawCollateralEvent(
        uint256 collateralId,
        address collateralOwner
    );

    /**
    * @dev create Collateral function, collateral will be stored in this contract
    * @param _collateralAddress is address of collateral
    * @param _packageId is id of pawn shop package
    * @param _amount is amount of token
    * @param _loanAsset is address of loan token
    * @param _expectedDurationQty is expected duration
    * @param _expectedDurationType is expected duration type
    */
    function createCollateral(
        address _collateralAddress,
        int256 _packageId,
        uint256 _amount,
        address _loanAsset,
        uint256 _expectedDurationQty,
        LoanDurationType _expectedDurationType
    ) 
        external 
        payable 
        whenContractNotPaused 
        returns (uint256 _idx) 
    {
        //check whitelist collateral token
        require(whitelistCollateral[_collateralAddress] == 1, '0'); //n-sup-col
        //validate: cannot use BNB as loanAsset
        require(_loanAsset != address(0), '1'); //bnb

        //id of collateral
        _idx = numberCollaterals;

        //create new collateral
        Collateral storage newCollateral = collaterals[_idx];
        
        newCollateral.create(
            _collateralAddress,
            _amount,
            _loanAsset,
            _expectedDurationQty,
            _expectedDurationType
        );

        ++numberCollaterals;

        emit CreateCollateralEvent(_idx, newCollateral);

        if (_packageId >= 0) {
            //Package must active
            PawnShopPackage storage pawnShopPackage = pawnShopPackages[uint256(_packageId)];
            require(pawnShopPackage.status == PawnShopPackageStatus.ACTIVE, '2'); //pack

            // Submit collateral to package
            CollateralAsLoanRequestListStruct storage loanRequestListStruct = collateralAsLoanRequestMapping[_idx];

            newCollateral.submitToLoanPackage(
                uint256(_packageId),
                loanRequestListStruct
            );

            emit SubmitPawnShopPackage(
                uint256(_packageId),
                _idx,
                LoanRequestStatus.PENDING
            );
        }

        // transfer to this contract
        PawnLib.safeTransfer(
            _collateralAddress,
            msg.sender,
            address(this),
            _amount
        );

        // Adjust reputation score
        reputation.adjustReputationScore(
            msg.sender,
            IReputation.ReasonType.BR_CREATE_COLLATERAL
        );
    }

    /**
    * @dev cancel collateral function and return back collateral
    * @param  _collateralId is id of collateral
    */
    function withdrawCollateral(uint256 _collateralId) 
        external 
        whenContractNotPaused 
    {
        Collateral storage collateral = collaterals[_collateralId];
        require(collateral.owner == msg.sender, '0'); //owner
        require(collateral.status == CollateralStatus.OPEN, '1'); //col

        PawnLib.safeTransfer(
            collateral.collateralAddress,
            address(this),
            collateral.owner,
            collateral.amount
        );

        // Remove relation of collateral and offers
        CollateralOfferList storage collateralOfferList = collateralOffersMapping[_collateralId];
        if (collateralOfferList.isInit == true) {
            for (uint256 i = 0; i < collateralOfferList.offerIdList.length; i++) {
                uint256 offerId = collateralOfferList.offerIdList[i];
                Offer storage offer = collateralOfferList.offerMapping[offerId];
                emit CancelOfferEvent(
                    offerId,
                    _collateralId,
                    offer.owner
                );
            }
            delete collateralOffersMapping[_collateralId];
        }

        delete collaterals[_collateralId];
        emit WithdrawCollateralEvent(_collateralId, msg.sender);

        // Adjust reputation score
        reputation.adjustReputationScore(
            msg.sender,
            IReputation.ReasonType.BR_CANCEL_COLLATERAL
        );
    }

    function updateCollateralStatus(
        uint256 _collateralId,
        CollateralStatus _status
    )
        external
        whenContractNotPaused
    {
        require(_msgSender() == address(pawnLoanContract) || _msgSender() == operator || _msgSender() == admin, "not-allow");

        Collateral storage collateral = collaterals[_collateralId];
        require(collateral.status == CollateralStatus.DOING, "invalid-col");

        collateral.status = _status;
    }

    /** ========================= OFFER FUNCTIONS & STATES ============================= */
    uint256 public numberOffers;

    mapping(uint256 => CollateralOfferList) public collateralOffersMapping;

    event CreateOfferEvent(
        uint256 offerId,
        uint256 collateralId,
        Offer data
    );

    event CancelOfferEvent(
        uint256 offerId,
        uint256 collateralId,
        address offerOwner
    );

    /**
    * @dev create Collateral function, collateral will be stored in this contract
    * @param _collateralId is id of collateral
    * @param _repaymentAsset is address of repayment token
    * @param _duration is duration of this offer
    * @param _loanDurationType is type for calculating loan duration
    * @param _repaymentCycleType is type for calculating repayment cycle
    * @param _liquidityThreshold is ratio of assets to be liquidated
    */
    function createOffer(
        uint256 _collateralId,
        address _repaymentAsset,
        uint256 _loanAmount,
        uint256 _duration,
        uint256 _interest,
        uint256 _loanDurationType,
        uint256 _repaymentCycleType,
        uint256 _liquidityThreshold
    )
        external 
        whenContractNotPaused 
        returns (uint256 _idx)
    {
        Collateral storage collateral = collaterals[_collateralId];
        require(collateral.status == CollateralStatus.OPEN, '0'); // col
        // validate not allow for collateral owner to create offer
        require(collateral.owner != msg.sender, '1'); // owner
        // Validate ower already approve for this contract to withdraw
        require(IERC20(collateral.loanAsset).allowance(msg.sender, address(this)) >= _loanAmount, '2'); // not-apr

        // Get offers of collateral
        CollateralOfferList storage collateralOfferList = collateralOffersMapping[_collateralId];
        if (!collateralOfferList.isInit) {
            collateralOfferList.isInit = true;
        }
        // Create offer id       
        _idx = numberOffers;

        // Create offer data
        Offer storage _offer = collateralOfferList.offerMapping[_idx];

        _offer.create(
            _repaymentAsset,
            _loanAmount,
            _duration,
            _interest,
            _loanDurationType,
            _repaymentCycleType,
            _liquidityThreshold
        );

        collateralOfferList.offerIdList.push(_idx);

        ++numberOffers;

        emit CreateOfferEvent(_idx, _collateralId, _offer);
        
        // Adjust reputation score
        reputation.adjustReputationScore(
            msg.sender,
            IReputation.ReasonType.LD_CREATE_OFFER
        );
    }

    /**
    * @dev cancel offer function, used for cancel offer
    * @param  _offerId is id of offer
    * @param _collateralId is id of collateral associated with offer
    */
    function cancelOffer(uint256 _offerId, uint256 _collateralId)
        external
        whenContractNotPaused
    {
        CollateralOfferList storage collateralOfferList = collateralOffersMapping[_collateralId];
        require(collateralOfferList.isInit == true, '0'); // col
        
        Offer storage offer = collateralOfferList.offerMapping[_offerId];

        offer.cancel(_offerId, collateralOfferList);

        delete collateralOfferList.offerIdList[collateralOfferList.offerIdList.length - 1];
        emit CancelOfferEvent(_offerId, _collateralId, msg.sender);
        
        // Adjust reputation score
        reputation.adjustReputationScore(
            msg.sender,
            IReputation.ReasonType.LD_CANCEL_OFFER
        );
    }

    /** ========================= PAWNSHOP PACKAGE FUNCTIONS & STATES ============================= */
    uint256 public numberPawnShopPackages;
    mapping(uint256 => PawnShopPackage) public pawnShopPackages;

    event CreatePawnShopPackage(
        uint256 packageId,
        PawnShopPackage data
    );

    event ChangeStatusPawnShopPackage(
        uint256 packageId,
        PawnShopPackageStatus status         
    );

    function createPawnShopPackage(
        PawnShopPackageType _packageType,
        address _loanToken,
        Range calldata _loanAmountRange,
        address[] calldata _collateralAcceptance,
        uint256 _interest,
        uint256 _durationType,
        Range calldata _durationRange,
        address _repaymentAsset,
        LoanDurationType _repaymentCycleType,
        uint256 _loanToValue,
        uint256 _loanToValueLiquidationThreshold
    ) 
        external 
        whenContractNotPaused
        returns (uint256 _idx)
    {
        _idx = numberPawnShopPackages;

        // Validataion logic: whitelist collateral, ranges must have upper greater than lower, duration type
        for (uint256 i = 0; i < _collateralAcceptance.length; i++) {
            require(whitelistCollateral[_collateralAcceptance[i]] == 1, '0'); // col
        }

        require(_loanAmountRange.lowerBound < _loanAmountRange.upperBound, '1'); // loan-rge
        require(_durationRange.lowerBound < _durationRange.upperBound, '2'); // dur-rge
        require(_durationType < 2, '3'); // dur-type
        
        require(_loanToken != address(0), '4'); // bnb

        //create new collateral
        PawnShopPackage storage newPackage = pawnShopPackages[_idx];

        newPackage.create(
            _packageType,
            _loanToken,
            _loanAmountRange,
            _collateralAcceptance,
            _interest,
            _durationType,
            _durationRange,
            _repaymentAsset,
            _repaymentCycleType,
            _loanToValue,
            _loanToValueLiquidationThreshold
        );

        ++numberPawnShopPackages;
        emit CreatePawnShopPackage(
            _idx, 
            newPackage
        );
        
        // Adjust reputation score
        reputation.adjustReputationScore(
            msg.sender,
            IReputation.ReasonType.LD_CREATE_PACKAGE
        );
    }

    function activePawnShopPackage(uint256 _packageId) external whenContractNotPaused {
        PawnShopPackage storage pawnShopPackage = pawnShopPackages[_packageId];
        require(pawnShopPackage.owner == msg.sender, '0'); // owner
        require(pawnShopPackage.status == PawnShopPackageStatus.INACTIVE, '1'); // pack

        pawnShopPackage.status = PawnShopPackageStatus.ACTIVE;
        emit ChangeStatusPawnShopPackage(
            _packageId,
            PawnShopPackageStatus.ACTIVE
        );
        
        // Adjust reputation score
        reputation.adjustReputationScore(
            msg.sender,
            IReputation.ReasonType.LD_REOPEN_PACKAGE
        );
    }

    function deactivePawnShopPackage(uint256 _packageId)
        external
        whenContractNotPaused
    {
        PawnShopPackage storage pawnShopPackage = pawnShopPackages[_packageId];
        
        // Deactivate package
        require(pawnShopPackage.owner == msg.sender, '0'); // owner
        require(pawnShopPackage.status == PawnShopPackageStatus.ACTIVE, '1'); // pack

        pawnShopPackage.status = PawnShopPackageStatus.INACTIVE;
        emit ChangeStatusPawnShopPackage(
            _packageId,
            PawnShopPackageStatus.INACTIVE
        );
        
        // Adjust reputation score
        reputation.adjustReputationScore(
            msg.sender,
            IReputation.ReasonType.LD_CANCEL_PACKAGE
        );
    }

    /** ========================= SUBMIT & ACCEPT WORKFLOW OF PAWNSHOP PACKAGE FUNCTIONS & STATES ============================= */
    
    mapping(uint256 => CollateralAsLoanRequestListStruct) public collateralAsLoanRequestMapping; // Map from collateral to loan request
    event SubmitPawnShopPackage(
        uint256 packageId,
        uint256 collateralId,
        LoanRequestStatus status
    );

    /**
    * @dev Submit Collateral to Package function, collateral will be submit to pawnshop package
    * @param _collateralId is id of collateral
    * @param _packageId is id of pawn shop package
    */
    function submitCollateralToPackage(
        uint256 _collateralId,
        uint256 _packageId
    ) 
        external 
        whenContractNotPaused
    {
        Collateral storage collateral = collaterals[_collateralId];
        require(collateral.owner == msg.sender, '0'); // owner
        require(collateral.status == CollateralStatus.OPEN, '1'); // col
        
        PawnShopPackage storage pawnShopPackage = pawnShopPackages[_packageId];
        require(pawnShopPackage.status == PawnShopPackageStatus.ACTIVE, '2'); // pack

        // VALIDATE HAVEN'T SUBMIT TO PACKAGE YET
        CollateralAsLoanRequestListStruct storage loanRequestListStruct = collateralAsLoanRequestMapping[_collateralId];
        
        if (loanRequestListStruct.isInit == true) {
            LoanRequestStatusStruct storage statusStruct = loanRequestListStruct.loanRequestToPawnShopPackageMapping[_packageId];

            require(statusStruct.isInit == false, '3'); // subed
        }

        // Save
        collateral.submitToLoanPackage(_packageId, loanRequestListStruct);
        emit SubmitPawnShopPackage(
            _packageId,
            _collateralId,
            LoanRequestStatus.PENDING
        );
    }

    function withdrawCollateralFromPackage(
        uint256 _collateralId,
        uint256 _packageId
    ) 
        external 
        whenContractNotPaused 
    {
        // Collateral must OPEN
        Collateral storage collateral = collaterals[_collateralId];
        require(collateral.status == CollateralStatus.OPEN, '0'); // col
        // Sender is collateral owner
        require(collateral.owner == msg.sender, '1'); // owner
        // collateral-package status must pending
        CollateralAsLoanRequestListStruct storage loanRequestListStruct = collateralAsLoanRequestMapping[_collateralId];
        LoanRequestStatusStruct storage loanRequestStatus = loanRequestListStruct.loanRequestToPawnShopPackageMapping[_packageId];
        require(loanRequestStatus.status == LoanRequestStatus.PENDING, '2'); // col-pack

        // _removeCollateralFromPackage(_collateralId, _packageId);

        collateral.removeFromLoanPackage(_packageId, loanRequestListStruct);
        emit SubmitPawnShopPackage(
            _packageId,
            _collateralId,
            LoanRequestStatus.CANCEL
        );
    }

    function acceptCollateralOfPackage(
        uint256 _collateralId,
        uint256 _packageId
    ) 
        external 
        whenContractNotPaused 
    {
        (
            Collateral storage collateral,
            PawnShopPackage storage pawnShopPackage,
            CollateralAsLoanRequestListStruct storage loanRequestListStruct,
            LoanRequestStatusStruct storage statusStruct
        ) = verifyCollateralPackageData(
                _collateralId,
                _packageId,
                CollateralStatus.OPEN,
                LoanRequestStatus.PENDING
            );
        
        // Check for owner of packageId
        require(pawnShopPackage.owner == msg.sender || msg.sender == operator, '0'); // owner-or-oper

        // Execute accept => change status of loan request to ACCEPTED, wait for system to generate contract
        // Update status of loan request between _collateralId and _packageId to Accepted
        statusStruct.status = LoanRequestStatus.ACCEPTED;
        collateral.status = CollateralStatus.DOING;

        // Remove status of loan request between _collateralId and other packageId then emit event Cancel
        for (uint256 i = 0; i < loanRequestListStruct.pawnShopPackageIdList.length; i++) {
            uint256 packageId = loanRequestListStruct.pawnShopPackageIdList[i];
            if (packageId != _packageId) {
                // Remove status
                delete loanRequestListStruct.loanRequestToPawnShopPackageMapping[packageId];
                emit SubmitPawnShopPackage(
                    packageId,
                    _collateralId,
                    LoanRequestStatus.CANCEL
                );
            }
        }
        delete loanRequestListStruct.pawnShopPackageIdList;
        loanRequestListStruct.pawnShopPackageIdList.push(_packageId);

        // Remove relation of collateral and offers
        CollateralOfferList storage collateralOfferList = collateralOffersMapping[_collateralId];
        if (collateralOfferList.isInit == true) {
            for (uint256 i = 0; i < collateralOfferList.offerIdList.length; i ++) {
                uint256 offerId = collateralOfferList.offerIdList[i];
                Offer storage offer = collateralOfferList.offerMapping[offerId];
                emit CancelOfferEvent(
                    offerId,
                    _collateralId,
                    offer.owner
                );
            }
            delete collateralOffersMapping[_collateralId];
        }
        emit SubmitPawnShopPackage(
            _packageId,
            _collateralId,
            LoanRequestStatus.ACCEPTED
        );

        emit SubmitPawnShopPackage(_packageId, _collateralId, LoanRequestStatus.ACCEPTED);
        
        generateContractForCollateralAndPackage(
            _collateralId, 
            _packageId
        );
    }

    function rejectCollateralOfPackage(
        uint256 _collateralId,
        uint256 _packageId
    ) 
        external 
        whenContractNotPaused 
    {
        (
            Collateral storage collateral,
            PawnShopPackage storage pawnShopPackage,
            CollateralAsLoanRequestListStruct storage loanRequestListStruct,

        ) = verifyCollateralPackageData(
                _collateralId,
                _packageId,
                CollateralStatus.OPEN,
                LoanRequestStatus.PENDING
            );
        require(pawnShopPackage.owner == msg.sender);

        // _removeCollateralFromPackage(_collateralId, _packageId);
        collateral.removeFromLoanPackage(_packageId, loanRequestListStruct);
        emit SubmitPawnShopPackage(
            _packageId,
            _collateralId,
            LoanRequestStatus.REJECTED
        );
    }

    function verifyCollateralPackageData(
        uint256 _collateralId,
        uint256 _packageId,
        CollateralStatus _requiredCollateralStatus,
        LoanRequestStatus _requiredLoanRequestStatus
    )
        internal
        view
        returns (
            Collateral storage collateral,
            PawnShopPackage storage pawnShopPackage,
            CollateralAsLoanRequestListStruct storage loanRequestListStruct,
            LoanRequestStatusStruct storage statusStruct
        )
    {
        collateral = collaterals[_collateralId];
        pawnShopPackage = pawnShopPackages[_packageId];
        loanRequestListStruct = collateralAsLoanRequestMapping[_collateralId];

        statusStruct = collateral.checkCondition(
            _packageId,
            pawnShopPackage,
            loanRequestListStruct,
            _requiredCollateralStatus,
            _requiredLoanRequestStatus
        );
    }

    /** ========================= CONTRACT RELATED FUNCTIONS & STATES ============================= */
    uint256 public numberContracts;
    mapping(uint256 => Contract) public contracts;
    
    /** ================================ 1. ACCEPT OFFER (FOR P2P WORKFLOWS) ============================= */
    event LoanContractCreatedEvent(
        uint256 exchangeRate,
        address fromAddress,
        uint256 contractId,
        Contract data
    );

    /**
    * @dev accept offer and create contract between collateral and offer
    * @param  _collateralId is id of collateral
    * @param  _offerId is id of offer
    */
    function acceptOffer(uint256 _collateralId, uint256 _offerId)
        external
        whenContractNotPaused
    {
        Collateral storage collateral = collaterals[_collateralId];
        require(msg.sender == collateral.owner, '0'); // owner
        require(collateral.status == CollateralStatus.OPEN, '1'); // col

        CollateralOfferList storage collateralOfferList = collateralOffersMapping[_collateralId];
        require(collateralOfferList.isInit == true, '2'); // col-off
        Offer storage offer = collateralOfferList.offerMapping[_offerId];
        require(offer.isInit == true, '3'); // not-sent
        require(offer.status == OfferStatus.PENDING, '4'); // unavail

        // Prepare contract raw data
        // TODO: @QuangVM: Calculate Exchange rate
        ContractRawData memory contractData = ContractRawData(
            _collateralId,
            collateral.owner,
            collateral.loanAsset,
            collateral.collateralAddress,
            collateral.amount,
            -1,
            int256(_offerId),
            0, /* Exchange rate */
            offer.loanAmount,
            offer.owner, 
            offer.repaymentAsset, 
            offer.interest, 
            offer.loanDurationType, 
            offer.liquidityThreshold,
            offer.duration
        );

        // Create Contract
        uint256 contractId = pawnLoanContract.createContract(contractData);
        
        // change status of offer and collateral
        offer.status = OfferStatus.ACCEPTED;
        collateral.status = CollateralStatus.DOING;

        // Cancel other offer sent to this collateral
        for (uint256 i = 0; i < collateralOfferList.offerIdList.length; i++) {
            uint256 thisOfferId = collateralOfferList.offerIdList[i];
            if (thisOfferId != _offerId) {
                Offer storage thisOffer = collateralOfferList.offerMapping[thisOfferId];
                emit CancelOfferEvent(
                    i,
                    _collateralId, 
                    thisOffer.owner
                );

                delete collateralOfferList.offerMapping[thisOfferId];
            }
        }
        delete collateralOfferList.offerIdList;
        collateralOfferList.offerIdList.push(_offerId);

        // transfer loan asset to collateral owner
        PawnLib.safeTransfer(
            collateral.loanAsset,
            offer.owner,
            collateral.owner,
            offer.loanAmount
        );

        // transfer collateral to LoanContract
        PawnLib.safeTransfer(
            collateral.collateralAddress,
            address(this),
            address(pawnLoanContract),
            collateral.amount
        );

        // PawnLib.safeTransfer(
        //     newContract.terms.loanAsset,
        //     newContract.terms.lender,
        //     newContract.terms.borrower,
        //     newContract.terms.loanAmount
        // );

        // Adjust reputation score
        reputation.adjustReputationScore(
            msg.sender,
            IReputation.ReasonType.BR_ACCEPT_OFFER
        );
        reputation.adjustReputationScore(
            offer.owner,
            IReputation.ReasonType.LD_ACCEPT_OFFER
        );
       pawnLoanContract.closePaymentRequestAndStartNew(0, contractId, PaymentRequestTypeEnum.INTEREST); 
    }

    /** ================================ 2. ACCEPT COLLATERAL (FOR PAWNSHOP PACKAGE WORKFLOWS) ============================= */
    /**
    * @dev create contract between package and collateral
    * @param  _collateralId is id of collateral
    * @param  _packageId is id of package
    */
    function generateContractForCollateralAndPackage(
        uint256 _collateralId,
        uint256 _packageId
    ) 
        internal 
        whenContractNotPaused 
        onlyOperator 
    {
        (
            Collateral storage collateral,
            PawnShopPackage storage pawnShopPackage,
            ,
            LoanRequestStatusStruct storage statusStruct
        ) = verifyCollateralPackageData(
                _collateralId,
                _packageId,
                CollateralStatus.DOING,
                LoanRequestStatus.ACCEPTED
            );

        // function tinh loanAmount va Exchange Rate trong contract Exchange.
        (
            uint256 loanAmount, 
            uint256 exchangeRate
        ) = exchange.calculateLoanAmountAndExchangeRate(
                collaterals[_collateralId], 
                pawnShopPackages[_packageId]
            );

        // Prepare contract raw data
        ContractRawData memory contractData = ContractRawData(
            _collateralId,
            collateral.owner,
            collateral.loanAsset,
            collateral.collateralAddress,
            collateral.amount,
            int256(_packageId),
            -1,
            exchangeRate,
            loanAmount,
            pawnShopPackage.owner,
            pawnShopPackage.repaymentAsset,
            pawnShopPackage.interest,
            pawnShopPackage.repaymentCycleType, 
            pawnShopPackage.loanToValueLiquidationThreshold,
            collateral.expectedDurationQty
        );
        // Create Contract
        uint256 contractId = pawnLoanContract.createContract(contractData);
        
        // Change status of collateral loan request to package to CONTRACTED
        statusStruct.status == LoanRequestStatus.CONTRACTED;
        emit SubmitPawnShopPackage(
            _packageId,
            _collateralId,
            LoanRequestStatus.CONTRACTED
        );

        // Transfer loan token from lender to borrower
        PawnLib.safeTransfer(
            collateral.loanAsset,
            pawnShopPackage.owner,
            collateral.owner,
            loanAmount
        );

        // transfer collateral to LoanContract
        PawnLib.safeTransfer(
            collateral.collateralAddress,
            address(this),
            address(pawnLoanContract),
            collateral.amount
        );

        // PawnLib.safeTransfer(
        //     newContract.terms.loanAsset,
        //     newContract.terms.lender,
        //     newContract.terms.borrower,
        //     newContract.terms.loanAmount
        // );
        
        // Adjust reputation score
        reputation.adjustReputationScore(
            pawnShopPackage.owner,
            IReputation.ReasonType.LD_GENERATE_CONTRACT
        );

        //ki dau tien BEId = 0
        pawnLoanContract.closePaymentRequestAndStartNew(0, contractId, PaymentRequestTypeEnum.INTEREST);
    }

    /** ================================ 3. PAYMENT REQUEST & REPAYMENT WORKLOWS ============================= */
    /** ===================================== 3.1. PAYMENT REQUEST ============================= */
    mapping(uint256 => PaymentRequest[]) public contractPaymentRequestMapping;
    
    event PaymentRequestEvent (
        int256 paymentRequestId,
        uint256 contractId,
        PaymentRequest data
    );

    /** ===================================== 3.2. REPAYMENT ============================= */
    event RepaymentEvent(
        uint256 contractId,
        uint256 paidPenaltyAmount,
        uint256 paidInterestAmount,
        uint256 paidLoanAmount,
        uint256 paidPenaltyFeeAmount,
        uint256 paidInterestFeeAmount,
        uint256 prepaidAmount,
        uint256 paymentRequestId,
        uint256 UID
    );

    /** ===================================== 3.3. LIQUIDITY & DEFAULT ============================= */
    // enum ContractLiquidedReasonType { LATE, RISK, UNPAID }
    event ContractLiquidedEvent(
        uint256 contractId,
        uint256 liquidedAmount,
        uint256 feeAmount,
        ContractLiquidedReasonType reasonType         
    );
    event LoanContractCompletedEvent(uint256 contractId);
    
    
    function releaseTrappedCollateralLockedWithoutContract(
        uint256 _collateralId,
        uint256 _packageId
    ) external onlyAdmin {
        // Validate: Collateral must Doing
        Collateral storage collateral = collaterals[_collateralId];
        require(collateral.status == CollateralStatus.DOING, '0'); // col

        // Check for collateral not being in any contract
        for (uint256 i = 0; i < numberContracts - 1; i ++) {
            Contract storage mContract = contracts[i];
            require(mContract.collateralId != _collateralId, '1'); // col-in-cont
        }

        // Check for collateral-package status is ACCEPTED
        CollateralAsLoanRequestListStruct storage loanRequestListStruct = collateralAsLoanRequestMapping[_collateralId];
        require(loanRequestListStruct.isInit == true, '2'); // col-loan-req
        LoanRequestStatusStruct storage statusStruct = loanRequestListStruct.loanRequestToPawnShopPackageMapping[_packageId];
        require(statusStruct.isInit == true, '3'); // col-loan-req-pack
        require(statusStruct.status == LoanRequestStatus.ACCEPTED, '4'); // not-acpt

        // Update status of loan request
        statusStruct.status = LoanRequestStatus.PENDING;
        collateral.status = CollateralStatus.OPEN;
    }

    /** ===================================== CONTRACT ADMIN ============================= */

    event AdminChanged(address _from, address _to);

    function changeAdmin(address newAddress) external onlyAdmin {
        address oldAdmin = admin;
        admin = newAddress;

        emit AdminChanged(oldAdmin, newAddress);
    }

    /** ===================================== REPUTATION FUNCTIONS & STATES ===================================== */

    IReputation public reputation;
    
    function setReputationContract(address _reputationAddress)
        external
        onlyAdmin
    {
        reputation = IReputation(_reputationAddress);
    }

    /** ==================== Exchange functions & states ==================== */
    Exchange public exchange;

    function setExchangeContract(address _exchangeAddress) 
        external 
        onlyAdmin
    {
        exchange = Exchange(_exchangeAddress);
    }

    /** ==================== Loan Contract functions & states ==================== */
    PawnLoanContract public pawnLoanContract;

    function setPawnLoanContract(address _pawnLoanAddress)
        external
        onlyAdmin
    {
        pawnLoanContract = PawnLoanContract(_pawnLoanAddress);
    }
}