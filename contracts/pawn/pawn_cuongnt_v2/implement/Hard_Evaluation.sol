// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "../interface/IDFY_Hard_Evaluation.sol";
import "../interface/IDFY_Hard_721.sol";
import "../interface/IDFY_Hard_1155.sol";
import "../../hub/Hub.sol";

contract Hard_Evaluation is
    Initializable,
    IDFY_Hard_Evaluation,
    ERC165Upgradeable,
    UUPSUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using CountersUpgradeable for CountersUpgradeable.Counter;
    using AddressUpgradeable for address;
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    // Total asset
    CountersUpgradeable.Counter public totalAssets;

    // Total evaluation
    CountersUpgradeable.Counter public totalEvaluations;

    // Address admin receiver fee
    address private addressAdmin;

    // Address minting fee
    address private mintingFeeAddress;

    // Assuming baseUri = "https://ipfs.io/ipfs"
    string public baseUri;

    // Mintting NFT fee
    uint256 public mintingNFTFee;

    // Mapping list asset
    // AssetId => Asset
    mapping(uint256 => Asset) public assetList;

    // Mapping from creator to asset
    // Creator => listAssetId
    mapping(address => uint256[]) public assetListOfOwner;

    // Mapping from creator address to assetId in his/her possession
    // Creator => (assetId => bool)
    mapping(address => mapping(uint256 => bool)) private assetsOfOwner;

    // Mapping list evaluation
    // EvaluationId => evaluation
    mapping(uint256 => Evaluation) public evaluationList;

    // Mapping from asset to list evaluation
    // AssetId => listEvaluationId
    mapping(uint256 => uint256[]) public evaluationByAsset;

    // Mapping from evaluator to evaluation
    // Evaluator => listEvaluation
    mapping(address => uint256[]) public evaluationListByEvaluator;

    // Mapping tokenId to asset
    // TokenId => asset
    mapping(uint256 => Asset) public tokenIdByAsset;

    // Mapping tokenId to evaluation
    // TokenId => evaluation
    mapping(uint256 => Evaluation) public tokenIdByEvaluation;

    function initialize(string memory _uri, address _mintingFeeAddress)
        public
        initializer
    {
        __Pausable_init();

        _setBaseURI(_uri);

        _setMintingNFTFee(50 * 10**18);

        _setAdminAddress(msg.sender);

        _setAddressMintingFee(_mintingFeeAddress);
    }

    function signature() external view override returns (bytes4) {
        return type(IDFY_Hard_Evaluation).interfaceId;
    }

    function _authorizeUpgrade(address) internal override {}

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC165Upgradeable, IERC165Upgradeable)
        returns (bool)
    {
        return
            interfaceId == type(IDFY_Hard_Evaluation).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function _setBaseURI(string memory _newURI) internal {
        require(bytes(_newURI).length > 0, "Empty URI");
        baseUri = _newURI;
    }

    // todo msg.sender = ADMIN_ROLE
    function setBaseURI(string memory _newURI) external override {
        _setBaseURI(_newURI);
    }

    function _setAdminAddress(address _newAdminAddress) internal {
        addressAdmin = _newAdminAddress;
    }

    // todo msg.sender = ADMIN_ROLE
    function setAdminAddress(address _newAdminAddress) external override {
        _setAdminAddress(_newAdminAddress);
    }

    function _setMintingNFTFee(uint256 _newFee) internal {
        mintingNFTFee = _newFee;
    }

    // todo msg.sender = ADMIN_ROLE
    function setMintingNFTFee(uint256 _newFee) external override {
        _setMintingNFTFee(_newFee);
    }

    function _setAddressMintingFee(address _newAddressMintingFee) internal {
        mintingFeeAddress = _newAddressMintingFee;
    }

    // todo msg.sender = ADMIN_ROLE
    function setAddressMintingFee(address _newAddressMintingFee)
        external
        override
    {
        _setAddressMintingFee(_newAddressMintingFee);
    }

    // todo msg.sender = ADMIN_ROLE
    function pause() external {
        _pause();
    }

    // todo msg.sender = ADMIN_ROLE
    function unpause() external {
        _unpause();
    }

    function createAssetRequest(
        string memory _assetCID,
        address _collectionAsset,
        uint256 _amount,
        CollectionStandard _collectionStandard
    ) external override whenNotPaused {
        // Require length _cid >0
        require(bytes(_assetCID).length > 0, "0"); // 0 asset cid empty

        // Create asset id
        uint256 _assetId = totalAssets.current();

        uint256 _amountAsset = 0;

        if (_collectionStandard == CollectionStandard.NFT_HARD_721) {
            _amountAsset = 1;
        } else {
            _amountAsset = _amount;
        }

        // Add asset from asset list
        assetList[_assetId] = Asset({
            assetCID: _assetCID,
            owner: msg.sender,
            collectionAddress: _collectionAsset,
            amount: _amountAsset,
            collectionStandard: _collectionStandard,
            status: AssetStatus.OPEN
        });

        // Add asset id from list asset id of owner
        assetListOfOwner[msg.sender].push(_assetId);

        // Update status from asset id of owner
        assetsOfOwner[msg.sender][_assetId] = true;

        // Update total asset
        totalAssets.increment();

        emit AssetEvent(_assetId, assetList[_assetId]);
    }

    // Function check asset of creator
    function _isAssetOfOwner(address _owner, uint256 _assetId)
        internal
        view
        returns (bool)
    {
        return assetsOfOwner[_owner][_assetId];
    }

    // todo msg.sender = evaluator role
    function evaluatedAsset(
        uint256 _assetId,
        address _currency,
        uint256 _price,
        string memory _evaluationCID,
        uint256 _depreciationRate
    ) external override whenNotPaused {
        // Check evaluation CID
        require(bytes(_evaluationCID).length > 0, "1"); // Evaluation CID empty.

        // Require address currency is contract except BNB - 0x0000000000000000000000000000000000000000
        if (_currency != address(0)) {
            require(_currency.isContract(), "2"); // Currency is not defined.
        }

        // Require validation of asset via _assetId
        require(_assetId >= 0, "3"); // Asset does not exist.

        // Require validation is creator asset
        require(!_isAssetOfOwner(msg.sender, _assetId), "4"); // Cant evaluted your asset.

        // Get asset to asset id;
        Asset memory _asset = assetList[_assetId];

        // Check asset is exists
        require(bytes(_asset.assetCID).length > 0, "5"); // Asset not exists.

        // check status asset
        require(_asset.status == AssetStatus.OPEN, "6"); // Asset not eveluated.

        // Create evaluation id
        uint256 _evaluationId = totalEvaluations.current();

        // Add evaluation to evaluationList
        evaluationList[_evaluationId] = Evaluation({
            assetId: _assetId,
            evaluationCID: _evaluationCID,
            depreciationRate: _depreciationRate,
            evaluator: msg.sender,
            currency: _currency,
            price: _price,
            collectionAddress: _asset.collectionAddress,
            collectionStandard: _asset.collectionStandard,
            status: EvaluationStatus.EVALUATED
        });

        // Add evaluation id to list evaluation of asset
        evaluationByAsset[_assetId].push(_evaluationId);

        // Add evaluation id to list evaluation of evaluator
        evaluationListByEvaluator[msg.sender].push(_evaluationId);

        // Update total evaluation
        totalEvaluations.increment();

        emit EvaluationEvent(
            _evaluationId,
            _asset,
            evaluationList[_evaluationId]
        );
    }

    function _checkDataAcceptOrReject(uint256 _assetId, uint256 _evaluationId)
        internal
        view
        returns (bool)
    {
        // Check creator is address 0
        require(msg.sender != address(0), "7"); // msg.sender must not be the zero address

        // Check asset id
        require(_assetId >= 0, "8"); // assetId must not be zero

        // Check evaluation index
        require(_evaluationId >= 0, "9"); // evaluationID must not be zero

        // Get asset to asset id;
        Asset memory _asset = assetList[_assetId];

        // Check asset to creator
        require(_asset.owner == msg.sender, "10"); // msg.sender must be the creator of the asset

        // Check asset is exists
        require(_asset.status == AssetStatus.OPEN, "11"); // asset status must be Open

        // approve an evaluation by looking for its index in the array.
        Evaluation memory _evaluation = evaluationList[_evaluationId];

        // Check status evaluation
        require(_evaluation.status == EvaluationStatus.EVALUATED, "12"); // evaluation status must be Evaluated

        return true;
    }

    function acceptEvaluation(uint256 _assetId, uint256 _evaluationId)
        external
        override
        whenNotPaused
    {
        // Check data
        require(_checkDataAcceptOrReject(_assetId, _evaluationId));

        // Get asset
        Asset storage _asset = assetList[_assetId];

        // Get evaluation
        Evaluation storage _evaluation = evaluationList[_evaluationId];

        // Update status evaluation
        _evaluation.status = EvaluationStatus.EVALUATION_ACCEPTED;

        // Reject all other evaluation of asset
        for (uint256 i = 0; i < evaluationByAsset[_assetId].length; i++) {
            if (evaluationByAsset[_assetId][i] != _evaluationId) {
                uint256 _evaluationIdReject = evaluationByAsset[_assetId][i];

                // Get evaluation
                Evaluation storage _otherEvaluation = evaluationList[
                    _evaluationIdReject
                ];

                // Update status evaluation
                _otherEvaluation.status = EvaluationStatus.EVALUATION_REJECTED;

                emit EvaluationEvent(
                    _evaluationIdReject,
                    _asset,
                    _otherEvaluation
                );
            }
        }

        // Update status asset
        _asset.status = AssetStatus.EVALUATED;

        emit EvaluationEvent(_evaluationId, _asset, _evaluation);
    }

    function rejectEvaluation(uint256 _assetId, uint256 _evaluationId)
        external
        override
        whenNotPaused
    {
        // Check data
        require(_checkDataAcceptOrReject(_assetId, _evaluationId));

        // Get asset
        Asset storage _asset = assetList[_assetId];

        // Get evaluation
        Evaluation storage _evaluation = evaluationList[_evaluationId];

        // Update status evaluation
        _evaluation.status = EvaluationStatus.EVALUATION_REJECTED;

        emit EvaluationEvent(_evaluationId, _asset, _evaluation);
    }

    // todo msg.sender = evaluator role
    function createNftToken(
        uint256 _assetId,
        uint256 _evaluationId,
        string memory _nftCID
    ) external override whenNotPaused nonReentrant {
        // Check nft CID
        require(bytes(_nftCID).length > 0, "13"); // NFT CID not be empty.

        // Check asset id
        require(_assetId >= 0, "14"); // Asset does not exists.

        // Get asset
        Asset storage _asset = assetList[_assetId];

        // Check asset CID
        require(bytes(_asset.assetCID).length > 0, "15"); // Asset does not exists

        // Check status asset
        require(_asset.status == AssetStatus.EVALUATED, "16"); // Asset have not evaluation.

        // Check evaluationId
        require(_evaluationId >= 0, "17"); // Evaluation does not exists.

        // Get evaluation
        Evaluation storage _evaluation = evaluationList[_evaluationId];

        // Check evaluation CID
        require(bytes(_evaluation.evaluationCID).length > 0, "18"); // Evaluation does not exists

        // Check status evaluation
        require(
            _evaluation.status == EvaluationStatus.EVALUATION_ACCEPTED,
            "19"
        ); // Evaluation is not acceptable.

        // Check evaluator
        require(msg.sender == _evaluation.evaluator, "20"); // Evaluator address does not match.

        // Check balance
        require(
            IERC20Upgradeable(mintingFeeAddress).balanceOf(msg.sender) >=
                (mintingNFTFee),
            "21"
        ); // Your balance is not enough.

        require(
            IERC20Upgradeable(mintingFeeAddress).allowance(
                msg.sender,
                address(this)
            ) >= (mintingNFTFee),
            "22"
        ); // You have not approve DFY.

        uint256 tokenId;

        if (_asset.collectionStandard == CollectionStandard.NFT_HARD_721) {
            tokenId = IDFY_Hard_721(_asset.collectionAddress).mint(
                msg.sender,
                _asset.owner,
                _nftCID
            );
        } else {
            tokenId = IDFY_Hard_1155(_asset.collectionAddress).mint(
                _asset.owner,
                msg.sender,
                _asset.amount,
                _nftCID,
                ""
            );
        }

        // Tranfer minting fee to admin
        IERC20Upgradeable(mintingFeeAddress).transferFrom(
            msg.sender,
            addressAdmin,
            mintingNFTFee
        );

        // Update status asset
        _asset.status = AssetStatus.NFT_CREATED;

        // Update status evaluation
        _evaluation.status = EvaluationStatus.NFT_CREATED;

        // Add token id to list asset of owner
        tokenIdByAsset[tokenId] = _asset;

        // Add token id to list nft of evaluator
        tokenIdByEvaluation[tokenId] = _evaluation;

        emit NFTEvent(tokenId, _asset.owner, _nftCID);
    }

    Hub public hubContract;

    function setContractHub(address _contractHubAddress) external {
        hubContract = Hub(_contractHubAddress);
    }
}
