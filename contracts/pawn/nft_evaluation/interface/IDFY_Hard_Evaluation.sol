// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../../../base/BaseInterface.sol";

interface IDFYHardEvaluation is BaseInterface {
    /* ===== Enum ===== */
    enum AssetStatus {
        OPEN,
        APPOINTED,
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

    enum EvaluatorStatus {
        ACCEPTED,
        CANCELLED
    }

    /* ===== Data type ===== */
    struct Asset {
        string assetCID;
        address owner;
        address collectionAddress;
        uint256 expectingPrice;
        address expectingPriceAddress;
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
        uint256 timeOfEvaluation;
        CollectionStandard collectionStandard;
        EvaluationStatus status;
    }

    // struct WhiteListFee {
    //     uint256 EvaluationFee;
    //     uint256 MintingFee;
    // }

    /* ===== Event ===== */
    event AssetEvent(uint256 assetId, Asset asset);

    event AppointmentEvent(
        uint256 appoimentId,
        Asset asset,
        Appointment appointment,
        string reason,
        uint256 appointmentTime
    );

    event EvaluationEvent(
        uint256 evaluationId,
        Asset asset,
        Evaluation evaluation
    );

    event NFTEvent(
        uint256 tokenId,
        string nftCID,
        uint256 amount,
        Asset asset,
        Evaluation evaluation,
        uint256 evaluationId
    );

    event EvaluatorEvent(
        uint256 evaluatorId,
        address evaluator,
        EvaluatorStatus evaluatorStatus
    );

    /* ===== Method ===== */
    // function setAdminAddress() external;

    // function addWhiteListFee(
    //     address _newAddressFee,
    //     uint256 _newEvaluationFee,
    //     uint256 _newMintingFee
    // ) external;

    function createAssetRequest(
        string memory _assetCID,
        address _collectionAsset,
        uint256 _expectingPrice,
        address _expectingPriceAddress,
        CollectionStandard _collectionStandard
    ) external;

    function createAppointment(
        uint256 _assetId,
        address _evaluator,
        address _evaluationFeeAddress,
        uint256 _appointmentTime
    ) external;

    function acceptAppointment(uint256 _appointmentId, uint256 _appointmentTime)
        external;

    function rejectAppointment(uint256 _appointmentId, string memory reason)
        external;

    function cancelAppointment(uint256 _appointmentId, string memory reason)
        external;

    function evaluateAsset(
        address _currency,
        uint256 _appointmentId,
        uint256 _price,
        string memory _evaluationCID,
        uint256 _depreciationRate,
        address _mintingFeeAddress
    ) external;

    function acceptEvaluation(uint256 _evaluationId) external;

    function rejectEvaluation(uint256 _evaluationId) external;

    function createNftToken(
        uint256 _evaluationId,
        uint256 _amount,
        string memory _nftCID
    ) external;

    function getEvaluationWithTokenId(
        address _addressCollection,
        uint256 _tokenId
    )
        external
        view
        returns (
            address _currency,
            uint256 _price,
            uint256 _depreciationRate,
            CollectionStandard _collectionStandard
        );
}
