// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165CheckerUpgradeable.sol";
import "../../../hub/HubLib.sol";
import "../../../hub/HubInterface.sol";
import "../../../base/BaseContract.sol";
import "../interface/IDFY_Hard_Evaluation.sol";
import "../interface/IDFY_Hard_721.sol";
import "../interface/IDFY_Hard_1155.sol";

contract HardEvaluation is IDFYHardEvaluation, BaseContract {
    using CountersUpgradeable for CountersUpgradeable.Counter;
    using AddressUpgradeable for address;
    using SafeMathUpgradeable for uint256;
    using ERC165CheckerUpgradeable for address;

    // Admin address
    // address public adminAdress;
    // address public hubContract;

    // Total asset
    CountersUpgradeable.Counter private _totalAssets;

    // Total appointment
    CountersUpgradeable.Counter private _totalAppointment;

    // Total evaluation
    CountersUpgradeable.Counter private _totalEvaluation;

    // white list Fee
    //   mapping(address => WhiteListFee) public WhiteListFees;

    // Mapping asset list
    // Asset id => Asset
    mapping(uint256 => Asset) public assetList;

    // Mapping appointment list
    // Appointmenty
    mapping(uint256 => Appointment) public appointmentList;

    // Mapping list appointment of asset
    // Asset id => list appointment id
    mapping(uint256 => uint256[]) public appointmentListOfAsset;

    mapping(address => mapping(uint256 => Evaluation))
        public evaluationWithTokenId;

    // Mapping evaluation list
    // Evaluation id => list evaluation
    mapping(uint256 => Evaluation) public evaluationList;

    // Mapping list evaluation of asset
    // Asset id => list evaluation id;
    mapping(uint256 => uint256[]) public evaluationListOfAsset;

    modifier onlyEvaluator() {
        _onlyRole(HubRoles.EVALUATOR_ROLE);
        _;
    }

    function initialize(address _hubContract) public initializer {
        __BaseContract_init(_hubContract);
    }

    /** ==================== Standard interface function implementations ==================== */

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC165Upgradeable, IERC165Upgradeable)
        returns (bool)
    {
        return
            interfaceId == type(IDFYHardEvaluation).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function signature() public pure override returns (bytes4) {
        return type(IDFYHardEvaluation).interfaceId;
    }

    function acceptEvaluator(uint256 evaluatorId, address requestEvaluator)
        external
        onlyOperator
    {
        // kiem tra xem requestEvaluator da la evaluator hay chua.
        require(
            IAccessControlUpgradeable(contractHub).hasRole(
                HubRoles.EVALUATOR_ROLE,
                requestEvaluator
            ),
            "is Evaluator"
        );

        // gan quyen evaluator
        IAccessControlUpgradeable(contractHub).grantRole(
            HubRoles.EVALUATOR_ROLE,
            requestEvaluator
        );

        // event khi thuc hien xong gan quyen
        emit EvaluatorEvent(
            evaluatorId,
            requestEvaluator,
            EvaluatorStatus.ACCEPTED
        );
    }

    function removeEvaluator(uint256 evaluatorId, address evaluator)
        external
        onlyOperator
    {
        // kiem tra xem co quyen evaluator hay khong
        require(
            !IAccessControlUpgradeable(contractHub).hasRole(
                HubRoles.EVALUATOR_ROLE,
                evaluator
            ),
            "is not Evaluator"
        );

        // thuc hien thu hoi  quyen evaluator
        IAccessControlUpgradeable(contractHub).revokeRole(
            HubRoles.EVALUATOR_ROLE,
            evaluator
        );
        // event sau khi thu hoi quyen
        emit EvaluatorEvent(evaluatorId, evaluator, EvaluatorStatus.CANCELLED);
    }

    // function addWhiteListFee(
    //     address newAddressFee,
    //     uint256 newEvaluationFee,
    //     uint256 newMintingFee
    // ) external override onlyAdmin {
    //     // khong dung den ham nay
    //     // _addWhitelistedFee(newAddressFee, newEvaluationFee, newMintingFee);
    // }

    function getEvaluationWithTokenId(
        address addressCollection,
        uint256 tokenId
    )
        external
        view
        override
        returns (
            address currency,
            uint256 price,
            uint256 depreciationRate,
            CollectionStandard collectionStandard
        )
    {
        currency = evaluationWithTokenId[addressCollection][tokenId].currency;

        price = evaluationWithTokenId[addressCollection][tokenId].price;

        depreciationRate = evaluationWithTokenId[addressCollection][tokenId]
            .depreciationRate;

        collectionStandard = evaluationWithTokenId[addressCollection][tokenId]
            .collectionStandard;
    }

    function createAssetRequest(
        string memory assetCID,
        address collectionAsset,
        uint256 expectingPrice,
        address expectingPriceAddress,
        CollectionStandard collectionStandard
    ) external override whenNotPaused {
        // Require asset CID
        require(bytes(assetCID).length > 0, "Asset CID is blank");

        if (collectionStandard == CollectionStandard.NFT_HARD_721) {
            require(
                collectionAsset.supportsInterface(
                    type(IDFYHard721).interfaceId
                ),
                "Unsupported Hard NFT-721 interface"
            ); // Invalid Collection
        } else if (collectionStandard == CollectionStandard.NFT_HARD_1155) {
            require(
                collectionAsset.supportsInterface(
                    type(IDFYHard1155).interfaceId
                ),
                "Unsupported Hard NFT-1155 interface"
            );
        } else {
            require(
                collectionAsset.supportsInterface(
                    type(IDFYHard1155).interfaceId
                ),
                "Invalid collection"
            );
        }

        // Create asset id
        uint256 _assetId = _totalAssets.current();

        // Add asset from asset list
        assetList[_assetId] = Asset({
            assetCID: assetCID,
            owner: msg.sender,
            collectionAddress: collectionAsset,
            expectingPrice: expectingPrice,
            expectingPriceAddress: expectingPriceAddress,
            collectionStandard: collectionStandard,
            status: AssetStatus.OPEN
        });

        // Update total asset
        _totalAssets.increment();

        emit AssetEvent(_assetId, assetList[_assetId]);
    }

    function createAppointment(
        uint256 assetId,
        address evaluator,
        address evaluationFeeAddress,
        uint256 appointmentTime
    ) external override whenNotPaused {
        // Get asset by asset id
        Asset storage _asset = assetList[assetId];

        require(
            bytes(_asset.assetCID).length > 0 &&
                _asset.status == AssetStatus.OPEN &&
                msg.sender == _asset.owner,
            "9"
        ); // Invalid asset

        // appointment time > 0
        require(appointmentTime > 0, "Appoint ment time > 0");

        require(!evaluator.isContract() && evaluator != _asset.owner, "11"); // Invalid evaluator

        // Gennerate total appointment
        uint256 _appointmentId = _totalAppointment.current();
        (uint256 _evaluationFee, ) = HubInterface(contractHub)
            .getEvaluationConfig(evaluationFeeAddress);

        // Add appointment to list appointment
        appointmentList[_appointmentId] = Appointment({
            assetId: assetId,
            assetOwner: _asset.owner,
            evaluator: evaluator,
            evaluationFee: _evaluationFee,
            evaluationFeeAddress: evaluationFeeAddress,
            status: AppointmentStatus.OPEN
        });

        // Add appointment id to appointment list of asset
        appointmentListOfAsset[assetId].push(_appointmentId);

        // update status asset
        _asset.status = AssetStatus.APPOINTED;

        // Transfer evaluation fee to smart contract
        CommonLib.safeTransfer(
            evaluationFeeAddress,
            msg.sender,
            address(this),
            _evaluationFee
        );

        // Update total appoinment
        _totalAppointment.increment();

        // Send event
        emit AppointmentEvent(
            _appointmentId,
            _asset,
            appointmentList[_appointmentId],
            "",
            appointmentTime
        );
    }

    function acceptAppointment(uint256 appointmentId, uint256 appointmentTime)
        external
        override
        onlyEvaluator
        whenNotPaused
    {
        Appointment storage _appointment = appointmentList[appointmentId];

        require(
            _appointment.status == AppointmentStatus.OPEN &&
                _appointment.evaluator == msg.sender,
            "12"
        ); // Invalid appoinment

        _appointment.status = AppointmentStatus.ACCEPTED;

        emit AppointmentEvent(
            appointmentId,
            assetList[_appointment.assetId],
            _appointment,
            "",
            appointmentTime
        );
    }

    function rejectAppointment(uint256 _appointmentId, string memory reason)
        external
        override
        onlyEvaluator
        whenNotPaused
    {
        Appointment storage _appointment = appointmentList[_appointmentId];

        require(
            _appointment.status == AppointmentStatus.OPEN &&
                _appointment.evaluator == msg.sender,
            "13"
        ); // Invalid appoinment

        _appointment.status = AppointmentStatus.REJECTED;

        Asset storage _asset = assetList[_appointment.assetId];

        _asset.status = AssetStatus.OPEN;

        CommonLib.safeTransfer(
            _appointment.evaluationFeeAddress,
            address(this),
            _appointment.assetOwner,
            _appointment.evaluationFee
        );

        emit AppointmentEvent(
            _appointmentId,
            assetList[_appointment.assetId],
            _appointment,
            reason,
            0
        );
    }

    function cancelAppointment(uint256 appointmentId, string memory reason)
        external
        override
    {
        Appointment storage _appointment = appointmentList[appointmentId];

        require(
            _appointment.status != AppointmentStatus.EVALUATED &&
                _appointment.status != AppointmentStatus.CANCELLED,
            "13"
        ); // Invalid appoinment

        _appointment.status = AppointmentStatus.CANCELLED;

        Asset storage _asset = assetList[_appointment.assetId];

        _asset.status = AssetStatus.OPEN;

        CommonLib.safeTransfer(
            _appointment.evaluationFeeAddress,
            address(this),
            _appointment.assetOwner,
            _appointment.evaluationFee
        );

        emit AppointmentEvent(
            appointmentId,
            assetList[_appointment.assetId],
            _appointment,
            reason,
            0
        );
    }

    function evaluatedAsset(
        address currency,
        uint256 appointmentId,
        uint256 price,
        string memory evaluationCID,
        uint256 depreciationRate,
        address mintingFeeAddress
    ) external override onlyEvaluator whenNotPaused {
        Appointment storage _appointment = appointmentList[appointmentId];

        require(
            _appointment.status == AppointmentStatus.ACCEPTED &&
                _appointment.evaluator == msg.sender,
            "14"
        ); // Invalid appoinment

        Asset storage _asset = assetList[_appointment.assetId];

        require(
            _asset.status == AssetStatus.APPOINTED &&
                _asset.owner != msg.sender,
            "15"
        ); // Invalid asset

        if (currency != address(0)) {
            require(currency.isContract(), "16"); // Invalid currency
        }

        require(
            bytes(evaluationCID).length > 0 &&
                price > 0 &&
                depreciationRate > 0,
            "17"
        ); // Invalid evaluation

        // Gennerate evaluation id
        uint256 evaluationId = _totalEvaluation.current();
        (, uint256 _mintingFee) = HubInterface(contractHub).getEvaluationConfig(
            mintingFeeAddress
        );

        evaluationList[evaluationId] = Evaluation({
            assetId: _appointment.assetId,
            appointmentId: appointmentId,
            evaluationCID: evaluationCID,
            depreciationRate: depreciationRate,
            evaluator: msg.sender,
            currency: currency,
            price: price,
            mintingFee: _mintingFee,
            mintingFeeAddress: mintingFeeAddress,
            collectionAddress: _asset.collectionAddress,
            timeOfEvaluation: block.timestamp,
            collectionStandard: _asset.collectionStandard,
            status: EvaluationStatus.EVALUATED
        });

        _appointment.status = AppointmentStatus.EVALUATED;

        CommonLib.safeTransfer(
            _appointment.evaluationFeeAddress,
            address(this),
            msg.sender,
            _appointment.evaluationFee
        );

        _totalEvaluation.increment();

        emit EvaluationEvent(
            evaluationId,
            _asset,
            evaluationList[evaluationId],
            ""
        );
    }

    function acceptEvaluation(uint256 evaluationId)
        external
        override
        whenNotPaused
    {
        Evaluation storage _evaluation = evaluationList[evaluationId];

        require(
            bytes(_evaluation.evaluationCID).length > 0 &&
                _evaluation.status == EvaluationStatus.EVALUATED,
            "18"
        ); // Invalid evaluation

        Asset storage _asset = assetList[_evaluation.assetId];

        require(
            bytes(_asset.assetCID).length > 0 &&
                _asset.status == AssetStatus.APPOINTED &&
                _asset.owner == msg.sender,
            "19"
        ); // Invalid asset

        _evaluation.status = EvaluationStatus.EVALUATION_ACCEPTED;

        for (
            uint256 i = 0;
            i < evaluationListOfAsset[_evaluation.assetId].length;
            i++
        ) {
            if (evaluationListOfAsset[_evaluation.assetId][i] != evaluationId) {
                uint256 _evaluationIdReject = evaluationListOfAsset[
                    _evaluation.assetId
                ][i];

                Evaluation storage _evaluationReject = evaluationList[
                    _evaluationIdReject
                ];

                if (
                    _evaluationReject.status !=
                    EvaluationStatus.EVALUATION_REJECTED
                ) {
                    _evaluationReject.status = EvaluationStatus
                        .EVALUATION_REJECTED;

                    emit EvaluationEvent(
                        _evaluationIdReject,
                        _asset,
                        _evaluationReject,
                        ""
                    );
                }
            }
        }

        _asset.status = AssetStatus.EVALUATED;

        CommonLib.safeTransfer(
            _evaluation.mintingFeeAddress,
            msg.sender,
            address(this),
            _evaluation.mintingFee
        );

        emit EvaluationEvent(evaluationId, _asset, _evaluation, "");
    }

    function rejectEvaluation(uint256 evaluationId, string memory reason)
        external
        override
        whenNotPaused
    {
        Evaluation storage _evaluation = evaluationList[evaluationId];

        require(
            bytes(_evaluation.evaluationCID).length > 0 &&
                _evaluation.status == EvaluationStatus.EVALUATED,
            "20"
        ); // Invalid evaluation

        Asset storage _asset = assetList[_evaluation.assetId];

        require(
            bytes(_asset.assetCID).length > 0 &&
                _asset.status == AssetStatus.APPOINTED &&
                _asset.owner == msg.sender,
            "21"
        ); // Invalid asset

        // Update status evaluation
        _evaluation.status = EvaluationStatus.EVALUATION_REJECTED;

        _asset.status = AssetStatus.OPEN;

        emit EvaluationEvent(evaluationId, _asset, _evaluation, "");
    }

    function createNftToken(
        uint256 evaluationId,
        uint256 amount,
        string memory nftCID
    ) external override onlyEvaluator whenNotPaused {
        require(bytes(nftCID).length > 0, "22"); // Invalid nftCID

        Evaluation storage _evaluation = evaluationList[evaluationId];

        require(
            bytes(_evaluation.evaluationCID).length > 0 &&
                _evaluation.status == EvaluationStatus.EVALUATION_ACCEPTED &&
                _evaluation.evaluator == msg.sender,
            "23"
        ); // Invalid evaluation

        Asset storage _asset = assetList[_evaluation.assetId];

        require(
            bytes(_asset.assetCID).length > 0 &&
                _asset.status == AssetStatus.EVALUATED,
            "21"
        ); // Invalid asset

        uint256 tokenId;

        if (_asset.collectionStandard == CollectionStandard.NFT_HARD_721) {
            tokenId = IDFYHard721(_asset.collectionAddress).mint(
                _asset.owner,
                nftCID,
                _evaluation.depreciationRate
            );
        } else {
            tokenId = IDFYHard1155(_asset.collectionAddress).mint(
                _asset.owner,
                amount,
                nftCID,
                "",
                _evaluation.depreciationRate
            );
        }

        (address feeWallet, ) = HubInterface(contractHub).getSystemConfig();

        CommonLib.safeTransfer(
            _evaluation.mintingFeeAddress,
            address(this),
            feeWallet,
            _evaluation.mintingFee
        );

        _asset.status = AssetStatus.NFT_CREATED;

        _evaluation.status = EvaluationStatus.NFT_CREATED;

        evaluationWithTokenId[_evaluation.collectionAddress][
            tokenId
        ] = _evaluation;

        emit NFTEvent(
            tokenId,
            nftCID,
            amount,
            _asset,
            _evaluation,
            evaluationId
        );
    }
}
