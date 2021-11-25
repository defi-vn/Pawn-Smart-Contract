// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/access/IAccessControlUpgradeable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./IPawn.sol";
import "../reputation/IReputation.sol";
import "../exchange/Exchange.sol";
import "../pawn-p2p-v2/ILoan.sol";
import "../hub/HubInterface.sol";
import "../hub/HubLib.sol";
import "../hub/Hub.sol";

contract PawnContract is IPawn, Ownable, Pausable, ReentrancyGuard {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using CollateralLib for Collateral;
    using OfferLib for Offer;
    using PawnPackageLib for PawnShopPackage;

    // mapping(address => uint256) public whitelistCollateral;
    // address public operator;
    // address public feeWallet = address(this);
    // uint256 public penaltyRate;
    // uint256 public systemFeeRate;
    // uint256 public lateThreshold;
    // uint256 public prepaidFeeRate;
    // uint256 public ZOOM;
    bool public initialized = false;
    address hubContract;

    //  address public admin;

    function initialize(address _HubContractAddress) external notInitialized {
        //  ZOOM = _zoom;
        initialized = true;
        hubContract = _HubContractAddress;
        //  admin = address(msg.sender);
    }

    function setContractHub(address _contractHubAddress) external onlyAdmin {
        hubContract = _contractHubAddress;
    }

    // function setOperator(address _newOperator) external onlyAdmin {
    //     operator = _newOperator;
    // }

    // function setFeeWallet(address _newFeeWallet) external onlyAdmin {
    //     feeWallet = _newFeeWallet;
    // }

    function pause() external onlyAdmin {
        _pause();
    }

    function unPause() external onlyAdmin {
        _unpause();
    }

    // /**
    //  * @dev set fee for each token
    //  * @param _feeRate is percentage of tokens to pay for the transaction
    //  */

    // function setSystemFeeRate(uint256 _feeRate) external onlyAdmin {
    //     systemFeeRate = _feeRate;
    // }

    // /**
    //  * @dev set fee for each token
    //  * @param _feeRate is percentage of tokens to pay for the penalty
    //  */
    // function setPenaltyRate(uint256 _feeRate) external onlyAdmin {
    //     penaltyRate = _feeRate;
    // }

    // /**
    //  * @dev set fee for each token
    //  * @param _threshold is number of time allowed for late repayment
    //  */
    // function setLateThreshold(uint256 _threshold) external onlyAdmin {
    //     lateThreshold = _threshold;
    // }

    // function setPrepaidFeeRate(uint256 _feeRate) external onlyAdmin {
    //     prepaidFeeRate = _feeRate;
    // }

    // function setWhitelistCollateral(address _token, uint256 _status)
    //     external
    //     onlyAdmin
    // {
    //     whitelistCollateral[_token] = _status;
    // }

    modifier notInitialized() {
        require(!initialized, "-2"); //initialized
        _;
    }

    modifier isInitialized() {
        require(initialized, "-3"); //not-initialized
        _;
    }

    function _onlyOperator() private view {
        require(
            IAccessControlUpgradeable(hubContract).hasRole(
                HubRoleLib.OPERATOR_ROLE,
                msg.sender
            ),
            "-0"
        );
    }

    modifier onlyOperator() {
        // require(operator == msg.sender, "operator");
        _onlyOperator();
        _;
    }

    function _onlyAdmin() private view {
        require(
            IAccessControlUpgradeable(hubContract).hasRole(
                HubRoleLib.DEFAULT_ADMIN_ROLE,
                msg.sender
            ),
            "-1"
        ); //admin
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

    function emergencyWithdraw(address _token)
        external
        override
        onlyAdmin
        whenPaused
    {
        PawnLib.safeTransfer(
            _token,
            address(this),
            msg.sender,
            PawnLib.calculateAmount(_token, address(this))
        );
    }

    /** ========================= COLLATERAL FUNCTIONS & STATES ============================= */
    uint256 public numberCollaterals;
    mapping(uint256 => Collateral) public collaterals;

    event CreateCollateralEvent(uint256 collateralId, Collateral data);

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
    ) external payable whenContractNotPaused returns (uint256 _idx) {
        //check whitelist collateral token
        // require(whitelistCollateral[_collateralAddress] == 1, "0"); //n-sup-col
        require(
            HubInterface(hubContract).getWhitelistCollateral(
                _collateralAddress
            ) == 1,
            "0"
        );
        //validate: cannot use BNB as loanAsset
        require(_loanAsset != address(0), "1"); //bnb

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

        // transfer to this contract
        PawnLib.safeTransfer(
            _collateralAddress,
            msg.sender,
            address(this),
            _amount
        );

        if (_packageId >= 0) {
            //Package must active
            PawnShopPackage storage pawnShopPackage = pawnShopPackages[
                uint256(_packageId)
            ];
            require(
                pawnShopPackage.status == PawnShopPackageStatus.ACTIVE,
                "2"
            ); //pack

            // _submitCollateralToPackage(_idx, uint256(_packageId));

            // Submit collateral to package
            CollateralAsLoanRequestListStruct
                storage loanRequestListStruct = collateralAsLoanRequestMapping[
                    _idx
                ];

            newCollateral.submitToLoanPackage(
                uint256(_packageId),
                loanRequestListStruct
            );

            emit SubmitPawnShopPackage(
                uint256(_packageId),
                _idx,
                LoanRequestStatus.PENDING
            );

            createContractForAutoPawnPackage(
                _idx,
                uint256(_packageId),
                newCollateral,
                pawnShopPackage
            );
        }

        // Adjust reputation score
        reputation.adjustReputationScore(
            msg.sender,
            IReputation.ReasonType.BR_CREATE_COLLATERAL
        );
    }

    function createContractForAutoPawnPackage(
        uint256 _collateralId,
        uint256 _packageId,
        Collateral storage _collateral,
        PawnShopPackage storage _pawnShopPackage
    ) internal {
        if (_pawnShopPackage.packageType == PawnShopPackageType.AUTO) {
            // Check if lender has enough balance and allowance for lending
            (bool sufficientBalance, ) = pawnLoanContract.checkLenderAccount(
                _collateral.collateralAddress,
                _collateral.amount,
                _pawnShopPackage.loanToValue,
                _pawnShopPackage.loanToken,
                _pawnShopPackage.repaymentAsset,
                _pawnShopPackage.owner,
                address(this)
            );

            // PawnLib.checkLenderAccount(loanAmount, pawnShopPackage.loanToken, pawnShopPackage.owner, address(this));

            // Lender has sufficient balance and allowance => process submitted collateral to contract
            if (sufficientBalance) {
                processLoanRequestToContract(_collateralId, _packageId);
            }
        }
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
        require(collateral.owner == msg.sender, "0"); //owner
        require(collateral.status == CollateralStatus.OPEN, "1"); //col

        PawnLib.safeTransfer(
            collateral.collateralAddress,
            address(this),
            collateral.owner,
            collateral.amount
        );

        // Remove relation of collateral and offers
        CollateralOfferList
            storage collateralOfferList = collateralOffersMapping[
                _collateralId
            ];
        if (collateralOfferList.isInit == true) {
            for (
                uint256 i = 0;
                i < collateralOfferList.offerIdList.length;
                i++
            ) {
                uint256 offerId = collateralOfferList.offerIdList[i];
                Offer storage offer = collateralOfferList.offerMapping[offerId];
                emit CancelOfferEvent(offerId, _collateralId, offer.owner);
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

    function _isValidCaller() private view {
        require(
            msg.sender == address(pawnLoanContract) ||
                IAccessControlUpgradeable(hubContract).hasRole(
                    HubRoleLib.OPERATOR_ROLE,
                    msg.sender
                ) ||
                IAccessControlUpgradeable(hubContract).hasRole(
                    HubRoleLib.DEFAULT_ADMIN_ROLE,
                    msg.sender
                ),
            "0"
        ); // caller not allowed
    }

    function _validateCollateral(uint256 _collateralId)
        private
        view
        returns (Collateral storage collateral)
    {
        collateral = collaterals[_collateralId];
        require(collateral.status == CollateralStatus.DOING, "1"); // invalid collateral
    }

    function updateCollateralStatus(
        uint256 _collateralId,
        CollateralStatus _status
    ) external override whenContractNotPaused {
        _isValidCaller();
        Collateral storage collateral = _validateCollateral(_collateralId);

        collateral.status = _status;
    }

    function updateCollateralAmount(uint256 _collateralId, uint256 _amount)
        external
        override
        whenContractNotPaused
    {
        _isValidCaller();
        Collateral storage collateral = _validateCollateral(_collateralId);

        collateral.amount = _amount;
    }

    /** ========================= OFFER FUNCTIONS & STATES ============================= */
    uint256 public numberOffers;

    mapping(uint256 => CollateralOfferList) public collateralOffersMapping;

    event CreateOfferEvent(uint256 offerId, uint256 collateralId, Offer data);

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
        uint8 _loanDurationType,
        uint8 _repaymentCycleType,
        uint256 _liquidityThreshold
    ) external whenContractNotPaused returns (uint256 _idx) {
        Collateral storage collateral = collaterals[_collateralId];

        require(collateral.status == CollateralStatus.OPEN, "0"); // col
        // validate not allow for collateral owner to create offer
        require(collateral.owner != msg.sender, "1"); // owner
        // Validate ower already approve for this contract to withdraw
        require(
            IERC20Upgradeable(collateral.loanAsset).allowance(
                msg.sender,
                address(this)
            ) >= _loanAmount,
            "2"
        ); // not-apr

        // Get offers of collateral
        CollateralOfferList
            storage collateralOfferList = collateralOffersMapping[
                _collateralId
            ];
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
        CollateralOfferList
            storage collateralOfferList = collateralOffersMapping[
                _collateralId
            ];
        require(collateralOfferList.isInit == true, "0"); // col
        // Lấy thông tin collateral
        // Collateral storage collateral = collaterals[_collateralId];
        Offer storage offer = collateralOfferList.offerMapping[_offerId];

        address offerOwner = offer.owner;

        offer.cancel(
            _offerId,
            collaterals[_collateralId].owner,
            collateralOfferList
        );

        // kiểm tra người gọi hàm -> rẽ nhánh event
        // neu nguoi goi la owner cua collateral  => reject offer.

        if (msg.sender == collaterals[_collateralId].owner) {
            emit CancelOfferEvent(_offerId, _collateralId, offerOwner);
        }

        // neu nguoi goi la owner cua offer thi canel offer
        if (msg.sender == offerOwner) {
            emit CancelOfferEvent(_offerId, _collateralId, msg.sender);

            // Adjust reputation score
            reputation.adjustReputationScore(
                msg.sender,
                IReputation.ReasonType.LD_CANCEL_OFFER
            );
        }
    }

    /** ========================= PAWNSHOP PACKAGE FUNCTIONS & STATES ============================= */
    uint256 public numberPawnShopPackages;
    mapping(uint256 => PawnShopPackage) public pawnShopPackages;

    event CreatePawnShopPackage(uint256 packageId, PawnShopPackage data);

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
    ) external whenContractNotPaused returns (uint256 _idx) {
        _idx = numberPawnShopPackages;

        // Validataion logic: whitelist collateral, ranges must have upper greater than lower, duration type
        for (uint256 i = 0; i < _collateralAcceptance.length; i++) {
            require(whitelistCollateral[_collateralAcceptance[i]] == 1, "0"); // col
        }

        require(_loanAmountRange.lowerBound < _loanAmountRange.upperBound, "1"); // loan-rge
        require(_durationRange.lowerBound < _durationRange.upperBound, "2"); // dur-rge
        require(_durationType < 2, "3"); // dur-type

        require(_loanToken != address(0), "4"); // bnb

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
        emit CreatePawnShopPackage(_idx, newPackage);

        // Adjust reputation score
        reputation.adjustReputationScore(
            msg.sender,
            IReputation.ReasonType.LD_CREATE_PACKAGE
        );
    }

    function activePawnShopPackage(uint256 _packageId)
        external
        whenContractNotPaused
    {
        PawnShopPackage storage pawnShopPackage = pawnShopPackages[_packageId];
        require(pawnShopPackage.owner == msg.sender, "0"); // owner
        require(pawnShopPackage.status == PawnShopPackageStatus.INACTIVE, "1"); // pack

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
        require(pawnShopPackage.owner == msg.sender, "0"); // owner
        require(pawnShopPackage.status == PawnShopPackageStatus.ACTIVE, "1"); // pack

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

    mapping(uint256 => CollateralAsLoanRequestListStruct)
        public collateralAsLoanRequestMapping; // Map from collateral to loan request
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
    ) external whenContractNotPaused {
        Collateral storage collateral = collaterals[_collateralId];
        require(collateral.owner == msg.sender, "0"); // owner
        require(collateral.status == CollateralStatus.OPEN, "1"); // col

        PawnShopPackage storage pawnShopPackage = pawnShopPackages[_packageId];
        require(pawnShopPackage.status == PawnShopPackageStatus.ACTIVE, "2"); // pack

        // VALIDATE HAVEN'T SUBMIT TO PACKAGE YET
        CollateralAsLoanRequestListStruct
            storage loanRequestListStruct = collateralAsLoanRequestMapping[
                _collateralId
            ];

        if (loanRequestListStruct.isInit == true) {
            LoanRequestStatusStruct storage statusStruct = loanRequestListStruct
                .loanRequestToPawnShopPackageMapping[_packageId];

            require(statusStruct.isInit == false, "3"); // subed
        }

        // Save
        collateral.submitToLoanPackage(_packageId, loanRequestListStruct);
        // _submitCollateralToPackage(_collateralId, _packageId);

        emit SubmitPawnShopPackage(
            _packageId,
            _collateralId,
            LoanRequestStatus.PENDING
        );

        createContractForAutoPawnPackage(
            _collateralId,
            _packageId,
            collateral,
            pawnShopPackage
        );
    }

    function withdrawCollateralFromPackage(
        uint256 _collateralId,
        uint256 _packageId
    ) external whenContractNotPaused {
        // Collateral must OPEN
        Collateral storage collateral = collaterals[_collateralId];
        require(collateral.status == CollateralStatus.OPEN, "0"); // col
        // Sender is collateral owner
        require(collateral.owner == msg.sender, "1"); // owner
        // collateral-package status must pending
        CollateralAsLoanRequestListStruct
            storage loanRequestListStruct = collateralAsLoanRequestMapping[
                _collateralId
            ];
        LoanRequestStatusStruct
            storage loanRequestStatus = loanRequestListStruct
                .loanRequestToPawnShopPackageMapping[_packageId];
        require(loanRequestStatus.status == LoanRequestStatus.PENDING, "2"); // col-pack

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
    ) external whenContractNotPaused {
        PawnShopPackage storage pawnShopPackage = pawnShopPackages[_packageId];

        // Check for owner of packageId
        require(
            pawnShopPackage.owner == msg.sender || msg.sender == operator,
            "0"
        ); // owner-or-oper

        processLoanRequestToContract(_collateralId, _packageId);
    }

    function rejectCollateralOfPackage(
        uint256 _collateralId,
        uint256 _packageId
    ) external whenContractNotPaused {
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

    function processLoanRequestToContract(
        uint256 _collateralId,
        uint256 _packageId
    ) internal whenContractNotPaused {
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

        // Execute accept => change status of loan request to ACCEPTED, wait for system to generate contract
        // Update status of loan request between _collateralId and _packageId to Accepted
        statusStruct.status = LoanRequestStatus.ACCEPTED;
        collateral.status = CollateralStatus.DOING;

        // Remove status of loan request between _collateralId and other packageId then emit event Cancel
        for (
            uint256 i = 0;
            i < loanRequestListStruct.pawnShopPackageIdList.length;
            i++
        ) {
            uint256 packageId = loanRequestListStruct.pawnShopPackageIdList[i];
            if (packageId != _packageId) {
                // Remove status
                delete loanRequestListStruct
                    .loanRequestToPawnShopPackageMapping[packageId];
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
        CollateralOfferList
            storage collateralOfferList = collateralOffersMapping[
                _collateralId
            ];
        if (collateralOfferList.isInit == true) {
            for (
                uint256 i = 0;
                i < collateralOfferList.offerIdList.length;
                i++
            ) {
                uint256 offerId = collateralOfferList.offerIdList[i];
                Offer storage offer = collateralOfferList.offerMapping[offerId];
                emit CancelOfferEvent(offerId, _collateralId, offer.owner);
            }
            delete collateralOffersMapping[_collateralId];
        }

        emit SubmitPawnShopPackage(
            _packageId,
            _collateralId,
            LoanRequestStatus.ACCEPTED
        );

        // Generate loan contract
        // generateContractForCollateralAndPackage(_collateralId, _packageId);
        generateContract(
            _collateralId,
            _packageId,
            collateral,
            pawnShopPackage,
            statusStruct
        );
    }

    /** ========================= CONTRACT RELATED FUNCTIONS & STATES ============================= */
    uint256 public numberContracts;
    mapping(uint256 => Contract) public contracts;

    /** ================================ 1. ACCEPT OFFER (FOR P2P WORKFLOWS) ============================= */
    // Old LoanContractCreatedEvent

    event LoanContractCreatedEvent(
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
        require(msg.sender == collateral.owner, "0"); // owner
        require(collateral.status == CollateralStatus.OPEN, "1"); // col

        CollateralOfferList
            storage collateralOfferList = collateralOffersMapping[
                _collateralId
            ];
        require(collateralOfferList.isInit == true, "2"); // col-off
        Offer storage offer = collateralOfferList.offerMapping[_offerId];
        require(offer.isInit == true, "3"); // not-sent
        require(offer.status == OfferStatus.PENDING, "4"); // unavail

        // Prepare contract raw data
        uint256 exchangeRate = exchange.exchangeRateofOffer(
            collateral.loanAsset,
            offer.repaymentAsset
        );
        ContractRawData memory contractData = ContractRawData(
            _collateralId,
            collateral.owner,
            collateral.loanAsset,
            collateral.collateralAddress,
            collateral.amount,
            -1,
            int256(_offerId),
            exchangeRate, /* Exchange rate */
            offer.loanAmount,
            offer.owner,
            offer.repaymentAsset,
            offer.interest,
            offer.loanDurationType,
            offer.liquidityThreshold,
            offer.duration
        );

        // Create Contract
        // uint256 contractId = pawnLoanContract.createContract(contractData);
        pawnLoanContract.createContract(contractData);

        // change status of offer and collateral
        offer.status = OfferStatus.ACCEPTED;
        collateral.status = CollateralStatus.DOING;

        // Cancel other offer sent to this collateral
        for (uint256 i = 0; i < collateralOfferList.offerIdList.length; i++) {
            uint256 thisOfferId = collateralOfferList.offerIdList[i];
            if (thisOfferId != _offerId) {
                Offer storage thisOffer = collateralOfferList.offerMapping[
                    thisOfferId
                ];
                emit CancelOfferEvent(i, _collateralId, thisOffer.owner);

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

        // Adjust reputation score
        reputation.adjustReputationScore(
            msg.sender,
            IReputation.ReasonType.BR_ACCEPT_OFFER
        );
        reputation.adjustReputationScore(
            offer.owner,
            IReputation.ReasonType.LD_ACCEPT_OFFER
        );
    }

    /** ================================ 2. ACCEPT COLLATERAL (FOR PAWNSHOP PACKAGE WORKFLOWS) ============================= */

    /**
     * @dev create contract between package and collateral
     * @param  _collateralId is id of collateral
     * @param  _packageId is id of package
     * @param  _collateral is the collateral being submitted to pawnshop package for creating loan request
     * @param  _pawnShopPackage is the pawnshop package where the collateral being sent to
     * @param  _statusStruct is the status object of the loan request generated when collateral is submitted to pawnshop package
     */
    function generateContract(
        uint256 _collateralId,
        uint256 _packageId,
        Collateral storage _collateral,
        PawnShopPackage storage _pawnShopPackage,
        LoanRequestStatusStruct storage _statusStruct
    ) internal whenContractNotPaused {
        (
            _collateral,
            _pawnShopPackage,
            ,
            _statusStruct
        ) = verifyCollateralPackageData(
            _collateralId,
            _packageId,
            CollateralStatus.DOING,
            LoanRequestStatus.ACCEPTED
        );

        // function tinh loanAmount va Exchange Rate trong contract Exchange.
        (uint256 loanAmount, uint256 exchangeRate) = exchange
            .calculateLoanAmountAndExchangeRate(_collateral, _pawnShopPackage);

        // Prepare contract raw data
        ContractRawData memory contractData = ContractRawData(
            _collateralId,
            _collateral.owner,
            _collateral.loanAsset,
            _collateral.collateralAddress,
            _collateral.amount,
            int256(_packageId),
            -1,
            exchangeRate,
            loanAmount,
            _pawnShopPackage.owner,
            _pawnShopPackage.repaymentAsset,
            _pawnShopPackage.interest,
            _pawnShopPackage.repaymentCycleType,
            _pawnShopPackage.loanToValueLiquidationThreshold,
            _collateral.expectedDurationQty
        );
        // Create Contract
        // uint256 contractId = pawnLoanContract.createContract(contractData);
        pawnLoanContract.createContract(contractData);

        // Change status of collateral loan request to package to CONTRACTED
        _statusStruct.status == LoanRequestStatus.CONTRACTED;
        emit SubmitPawnShopPackage(
            _packageId,
            _collateralId,
            LoanRequestStatus.CONTRACTED
        );

        // Transfer loan token from lender to borrower
        PawnLib.safeTransfer(
            _collateral.loanAsset,
            _pawnShopPackage.owner,
            _collateral.owner,
            loanAmount
        );

        // transfer collateral to LoanContract
        PawnLib.safeTransfer(
            _collateral.collateralAddress,
            address(this),
            address(pawnLoanContract),
            _collateral.amount
        );

        // Adjust reputation score
        reputation.adjustReputationScore(
            _pawnShopPackage.owner,
            IReputation.ReasonType.LD_GENERATE_CONTRACT
        );
    }

    /** ================================ 3. PAYMENT REQUEST & REPAYMENT WORKLOWS ============================= */
    /** ===================================== 3.1. PAYMENT REQUEST ============================= */
    mapping(uint256 => PaymentRequest[]) public contractPaymentRequestMapping;

    // Old PaymentRequestEvent
    event PaymentRequestEvent(uint256 contractId, PaymentRequest data);

    function closePaymentRequestAndStartNew(
        uint256 _contractId,
        uint256 _remainingLoan,
        uint256 _nextPhrasePenalty,
        uint256 _nextPhraseInterest,
        uint256 _dueDateTimestamp,
        PaymentRequestTypeEnum _paymentRequestType,
        bool _chargePrepaidFee
    ) external whenNotPaused onlyOperator {
        Contract storage currentContract = contractMustActive(_contractId);

        // Check if number of requests is 0 => create new requests, if not then update current request as LATE or COMPLETE and create new requests
        PaymentRequest[] storage requests = contractPaymentRequestMapping[
            _contractId
        ];
        if (requests.length > 0) {
            // not first phrase, get previous request
            PaymentRequest storage previousRequest = requests[
                requests.length - 1
            ];

            // Validate: time must over due date of current payment
            require(block.timestamp >= previousRequest.dueDateTimestamp, "0"); // time-not-due

            // Validate: remaining loan must valid
            require(previousRequest.remainingLoan == _remainingLoan, "1"); // remain

            // Validate: Due date timestamp of next payment request must not over contract due date
            require(
                _dueDateTimestamp <= currentContract.terms.contractEndDate,
                "2"
            ); // contr-end
            require(
                _dueDateTimestamp > previousRequest.dueDateTimestamp ||
                    _dueDateTimestamp == 0,
                "3"
            ); // less-th-prev

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
                if (
                    currentContract.terms.lateThreshold <=
                    currentContract.lateCount
                ) {
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
                if (
                    previousRequest.remainingInterest +
                        previousRequest.remainingPenalty +
                        previousRequest.remainingLoan >
                    0
                ) {
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

            emit PaymentRequestEvent(_contractId, previousRequest);
        } else {
            // Validate: remaining loan must valid
            require(currentContract.terms.loanAmount == _remainingLoan, "4"); // remain

            // Validate: Due date timestamp of next payment request must not over contract due date
            require(
                _dueDateTimestamp <= currentContract.terms.contractEndDate,
                "5"
            ); // contr-end
            require(
                _dueDateTimestamp > currentContract.terms.contractStartDate ||
                    _dueDateTimestamp == 0,
                "6"
            ); // less-th-prev
            require(
                block.timestamp < _dueDateTimestamp || _dueDateTimestamp == 0,
                "7"
            ); // over

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
        emit PaymentRequestEvent(_contractId, newRequest);
    }

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

    /**
        End lend period settlement and generate invoice for next period
     */
    function repayment(
        uint256 _contractId,
        uint256 _paidPenaltyAmount,
        uint256 _paidInterestAmount,
        uint256 _paidLoanAmount,
        uint256 _UID
    ) external whenNotPaused {
        // Get contract & payment request
        Contract storage _contract = contractMustActive(_contractId);
        PaymentRequest[] storage requests = contractPaymentRequestMapping[
            _contractId
        ];
        require(requests.length > 0, "0");
        PaymentRequest storage _paymentRequest = requests[requests.length - 1];

        // Validation: Contract must not overdue
        require(block.timestamp <= _contract.terms.contractEndDate, "1"); // contr-over

        // Validation: current payment request must active and not over due
        require(_paymentRequest.status == PaymentRequestStatusEnum.ACTIVE, "2"); // not-act
        if (_paidPenaltyAmount + _paidInterestAmount > 0) {
            require(block.timestamp <= _paymentRequest.dueDateTimestamp, "3"); // over-due
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
            _paymentRequest.requestId,
            _UID
        );

        // If remaining loan = 0 => paidoff => execute release collateral
        if (
            _paymentRequest.remainingLoan == 0 &&
            _paymentRequest.remainingPenalty == 0 &&
            _paymentRequest.remainingInterest == 0
        ) {
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
            uint256 transferAmount = _paidPenaltyAmount +
                _paidInterestAmount -
                _feePenalty -
                _feeInterest;
            PawnLib.safeTransfer(
                _contract.terms.repaymentAsset,
                msg.sender,
                _contract.terms.lender,
                transferAmount
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
    // enum ContractLiquidedReasonType { LATE, RISK, UNPAID }
    event ContractLiquidedEvent(
        uint256 contractId,
        uint256 liquidedAmount,
        uint256 feeAmount,
        ContractLiquidedReasonType reasonType
    );
    event LoanContractCompletedEvent(uint256 contractId);

    function collateralRiskLiquidationExecution(
        uint256 _contractId,
        uint256 _collateralPerRepaymentTokenExchangeRate,
        uint256 _collateralPerLoanAssetExchangeRate
    ) external whenNotPaused onlyOperator {
        // Validate: Contract must active
        Contract storage _contract = contractMustActive(_contractId);

        (
            uint256 remainingRepayment,
            uint256 remainingLoan
        ) = calculateRemainingLoanAndRepaymentFromContract(
                _contractId,
                _contract
            );
        uint256 valueOfRemainingRepayment = (_collateralPerRepaymentTokenExchangeRate *
                remainingRepayment) / ZOOM;
        uint256 valueOfRemainingLoan = (_collateralPerLoanAssetExchangeRate *
            remainingLoan) / ZOOM;
        uint256 valueOfCollateralLiquidationThreshold = (_contract
            .terms
            .collateralAmount * _contract.terms.liquidityThreshold) /
            (100 * ZOOM);

        require(
            valueOfRemainingLoan + valueOfRemainingRepayment >=
                valueOfCollateralLiquidationThreshold,
            "0"
        ); // under-thres

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
        PaymentRequest[] storage requests = contractPaymentRequestMapping[
            _contractId
        ];
        if (requests.length > 0) {
            // Have payment request
            PaymentRequest storage _paymentRequest = requests[
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

    function lateLiquidationExecution(uint256 _contractId)
        external
        whenNotPaused
    {
        // Validate: Contract must active
        Contract storage _contract = contractMustActive(_contractId);

        // validate: contract have lateCount == lateThreshold
        require(_contract.lateCount >= _contract.terms.lateThreshold, "0"); // not-reach

        // Execute: call internal liquidation
        _liquidationExecution(_contractId, ContractLiquidedReasonType.LATE);
    }

    function contractMustActive(uint256 _contractId)
        internal
        view
        returns (Contract storage _contract)
    {
        // Validate: Contract must active
        _contract = contracts[_contractId];
        require(_contract.status == ContractStatus.ACTIVE, "0"); // contr-act
    }

    function notPaidFullAtEndContractLiquidation(uint256 _contractId)
        external
        whenNotPaused
    {
        Contract storage _contract = contractMustActive(_contractId);
        // validate: current is over contract end date
        require(block.timestamp >= _contract.terms.contractEndDate, "0"); // due

        // validate: remaining loan, interest, penalty haven't paid in full
        (
            uint256 remainingRepayment,
            uint256 remainingLoan
        ) = calculateRemainingLoanAndRepaymentFromContract(
                _contractId,
                _contract
            );
        require(remainingRepayment + remainingLoan > 0, "1"); // paid

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
        uint256 _liquidAmount = _contract.terms.collateralAmount -
            _systemFeeAmount;

        // Execute: update status of contract to DEFAULT, collateral to COMPLETE
        _contract.status = ContractStatus.DEFAULT;
        PaymentRequest[]
            storage _paymentRequests = contractPaymentRequestMapping[
                _contractId
            ];
        PaymentRequest storage _lastPaymentRequest = _paymentRequests[
            _paymentRequests.length - 1
        ];
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

        emit PaymentRequestEvent(_contractId, _lastPaymentRequest);

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
        PaymentRequest[]
            storage _paymentRequests = contractPaymentRequestMapping[
                _contractId
            ];
        PaymentRequest storage _lastPaymentRequest = _paymentRequests[
            _paymentRequests.length - 1
        ];
        _lastPaymentRequest.status = PaymentRequestStatusEnum.COMPLETE;
        Collateral storage _collateral = collaterals[_contract.collateralId];
        _collateral.status = CollateralStatus.COMPLETED;

        // Emit event ContractCompleted
        emit LoanContractCompletedEvent(_contractId);
        emit PaymentRequestEvent(_contractId, _lastPaymentRequest);

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

    function releaseTrappedCollateralLockedWithoutContract(
        uint256 _collateralId,
        uint256 _packageId
    ) external onlyAdmin {
        // Validate: Collateral must Doing
        Collateral storage collateral = collaterals[_collateralId];
        require(collateral.status == CollateralStatus.DOING, "0"); // col

        // Check for collateral not being in any contract
        for (uint256 i = 0; i < numberContracts - 1; i++) {
            Contract storage mContract = contracts[i];
            require(mContract.collateralId != _collateralId, "1"); // col-in-cont
        }

        // Check for collateral-package status is ACCEPTED
        CollateralAsLoanRequestListStruct
            storage loanRequestListStruct = collateralAsLoanRequestMapping[
                _collateralId
            ];
        require(loanRequestListStruct.isInit == true, "2"); // col-loan-req
        LoanRequestStatusStruct storage statusStruct = loanRequestListStruct
            .loanRequestToPawnShopPackageMapping[_packageId];
        require(statusStruct.isInit == true, "3"); // col-loan-req-pack
        require(statusStruct.status == LoanRequestStatus.ACCEPTED, "4"); // not-acpt

        // Update status of loan request
        statusStruct.status = LoanRequestStatus.PENDING;
        collateral.status = CollateralStatus.OPEN;
    }

    /** ===================================== CONTRACT ADMIN ============================= */

    // event AdminChanged(address _from, address _to);

    // function changeAdmin(address newAddress) external onlyAdmin {
    //     address oldAdmin = admin;
    //     admin = newAddress;

    //     emit AdminChanged(oldAdmin, newAddress);
    // }

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

    function setExchangeContract(address _exchangeAddress) external onlyAdmin {
        exchange = Exchange(_exchangeAddress);
    }

    /** ==================== Loan Contract functions & states ==================== */
    ILoan public pawnLoanContract;

    function setPawnLoanContract(address _pawnLoanAddress) external onlyAdmin {
        pawnLoanContract = ILoan(_pawnLoanAddress);
    }

    /** ==================== User-reviews related functions ==================== */
    function getContractInfoForReview(uint256 _contractId)
        external
        view
        override
        returns (
            address borrower,
            address lender,
            ContractStatus status
        )
    {
        Contract storage _contract = contracts[_contractId];
        borrower = _contract.terms.borrower;
        lender = _contract.terms.lender;
        status = _contract.status;
    }

    /** ==================== Version 2.4 ==================== */
}
