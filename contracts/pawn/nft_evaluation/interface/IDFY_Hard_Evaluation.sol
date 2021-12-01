// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../../../base/BaseInterface.sol";

interface IDFY_Hard_Evaluation is BaseInterface {
    /* ===== Enum ===== */
    enum AssetStatus {
        OPEN,
        APPOINTMENTED,
        EVALUATED,
        NFT_CREATED
    }

    enum EvaluationStatus {
        EVALUATED,
        EVALUATION_ACCEPTED,
        EVALUATION_REJECTED,
        NFT_CREATED
    }

    enum CollectionStandard {
        NFT_HARD_721,
        NFT_HARD_1155
    }

    enum AppointmentStatus {
        OPEN,
        ACCEPTED,
        REJECTED,
        CANCELLED,
        EVALUATED
    }

    /* ===== Data type ===== */
    struct Asset {
        string assetCID;
        address owner;
        address collectionAddress;
        CollectionStandard collectionStandard;
        AssetStatus status;
    }

    struct Appointment {
        uint256 assetId;
        address assetOwner;
        address evaluator;
        uint256 evaluationFee;
        address evaluationFeeAddress;
        AppointmentStatus status;
    }

    struct Evaluation {
        uint256 assetId;
        uint256 appointmentId;
        string evaluationCID;
        uint256 depreciationRate;
        address evaluator;
        address currency;
        uint256 price;
        uint256 mintingFee;
        address mintingFeeAddress;
        address collectionAddress;
        CollectionStandard collectionStandard;
        EvaluationStatus status;
    }

    /* ===== Event ===== */
    event AssetEvent(uint256 assetId, Asset asset);

    event AppointmentEvent(
        uint256 appoimentId,
        Asset asset,
        Appointment appointment,
        string reason
    );

    event EvaluationEvent(
        uint256 evaluationId,
        Asset asset,
        Evaluation evaluation,
        string reason
    );

    event NFTEvent(
        uint256 tokenId,
        string nftCID,
        uint256 amount,
        Asset asset,
        Evaluation evaluation
    );

    /* ===== Method ===== */
    function setAdminAddress(address _newAdminAddress) external;

    function addWhiteListEvaluationFee(
        address _newAddressEvaluatonFee,
        uint256 _newEvaluationFee
    ) external;

    function addWhiteListMintingFee(
        address _newAddressMintingFee,
        uint256 _newMintingFee
    ) external;

    function createAssetRequest(
        string memory _assetCID,
        address _collectionAsset,
        CollectionStandard _collectionStandard
    ) external;

    function createAppointment(
        uint256 _assetId,
        address _evaluator,
        address _evaluationFeeAddress
    ) external;

    function acceptAppointment(uint256 _appointmentId) external;

    function rejectAppointment(uint256 _appointmentId, string memory reason)
        external;

    function cancelAppointment(uint256 _appointmentId, string memory reason)
        external;

    function evaluatedAsset(
        address _currency,
        uint256 _appointmentId,
        uint256 _price,
        string memory _evaluationCID,
        uint256 _depreciationRate,
        address _mintingFeeAddress
    ) external;

    function acceptEvaluation(uint256 _evaluationId) external;

    function rejectEvaluation(uint256 _evaluationId, string memory reason)
        external;

    function createNftToken(
        uint256 _evaluationId,
        uint256 _amount,
        string memory _nftCID
    ) external;
}
