// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "../../base/BaseInterface.sol";

interface EvaluationInterface is BaseInterface {
    /** Data Types */
    struct Asset {
        string assetDataCID;
        address creator;
        AssetStatus status;
    }

    struct Evaluation {
        uint256 assetId;
        string evaluationCID;
        uint256 depreciationRate;
        address evaluator;
        address token;
        uint256 price;
        EvaluationStatus status;
    }

    /** Enums */
    enum AssetStatus {
        OPEN,
        EVALUATED,
        NFT_CREATED
    }
    enum EvaluationStatus {
        EVALUATED,
        EVALUATION_ACCEPTED,
        EVALUATION_REJECTED,
        NFT_CREATED
    }

    /** Events */
    event AssetCreated(uint256 assetId, Asset asset);

    event AssetEvaluated(
        uint256 evaluationId,
        uint256 assetId,
        Asset asset,
        Evaluation evaluation
    );

    event ApproveEvaluator(address evaluator);

    /** Methods */
    function createAssetRequest(string memory _cid) external;

    function getAssetsByCreator(address _creator)
        external
        view
        returns (uint256[] memory);

    function evaluateAsset(
        uint256 _assetId,
        address _currency,
        uint256 _price,
        string memory _evaluationCID,
        uint256 _depreciationRate
    ) external;

    function acceptEvaluation(uint256 _assetId, uint256 _evaluationId) external;

    function rejectEvaluation(uint256 _assetId, uint256 _evaluationId) external;

    function createNftToken(
        uint256 _assetId,
        uint256 _evaluationId,
        string memory _nftCID
    ) external;
}
