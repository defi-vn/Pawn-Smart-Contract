// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../../base/BaseInterface.sol";

interface IDFY_Hard_Evaluation is BaseInterface{

    /** ===== Enum ===== */
    enum AssetStatus{
        OPEN,
        EVALUATED,
        NFT_CREATED
    }

    enum EvaluationStatus{
        EVALUATED,
        EVALUATION_ACCEPTED,
        EVALUATION_REJECTED,
        NFT_CREATED
    }

    enum CollectionStandard{
        NFT_HARD_721,
        NFT_HARD_1155
    }

    /** ===== Data type ===== */

    struct Asset {
        string assetCID;
        address owner;
        address collectionAddress;
        uint256 amount;
        CollectionStandard collectionStandard;
        AssetStatus status;
    }

    struct Evaluation {
        uint256 assetId;
        string evaluationCID;
        uint256 depreciationRate;
        address evaluator;
        address currency;
        uint256 price;
        address collectionAddress;
        CollectionStandard collectionStandard;
        EvaluationStatus status;
    }

    /** ===== event ===== */
    event AssetEvent (
        uint256 assetId,
        Asset asset
    );

    event EvaluationEvent (
        uint256 evaluationId,
        Asset asset,
        Evaluation evaluation
    );

    event NFTEvent (
        uint256 tokenId,
        address owner,
        string nftCID
    );
    
    /** ===== method ===== */

    function setBaseURI(
        string memory _newURI
    ) external;

    function setAdminAddress(
        address _newAdminAddress
    ) external;

    function setFeeWallet(
        address _newFeeWallet
    ) external;

    function setMintingNFTFee(
        uint256 _newFee
    ) external;

    function setAddressMintingFee(
        address _newAddressMintingFee
    ) external;

    function createAssetRequest(
        string memory _assetCID,
        address _collectionAsset,
        uint256 _amount,
        CollectionStandard _collectionStandard
    ) external;

    function evaluatedAsset(
        uint256 _assetId,
        address _currency,
        uint256 _price,
        string memory _evaluationCID,
        uint256 _depreciationRate
    ) external;

    function acceptEvaluation(
        uint256 _assetId,
        uint256 _evaluationId
    ) external;

    function rejectEvaluation(
        uint256 _assetId,
        uint256 _evaluationId
    ) external;

    function createNftToken(
        uint256 _assetId,
        uint256 _evaluationId,
        string memory _nftCID
    ) external;

}