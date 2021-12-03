// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165CheckerUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/IAccessControlUpgradeable.sol";
import "../interface/IDFY_Hard_Evaluation.sol";
import "../interface/IDFY_Hard_721.sol";
import "../interface/IDFY_Hard_1155.sol";
import "./Hard_Evaluation_Lib.sol";
import "../../hub/HubLib.sol";
import "../../hub/HubInterface.sol";
import "../../../base/BaseContract.sol";

contract Hard_Evaluation is
    Initializable,
    UUPSUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    ERC165Upgradeable,
    IDFY_Hard_Evaluation,
    BaseContract
{
    using CountersUpgradeable for CountersUpgradeable.Counter;
    using AddressUpgradeable for address;
    using SafeMathUpgradeable for uint256;
    using ERC165CheckerUpgradeable for address;

    // Admin address
    address public adminAdress;
    address public hubContract;

    // Total asset
    CountersUpgradeable.Counter private _totalAssets;

    // Total appointment
    CountersUpgradeable.Counter private _totalAppointment;

    // Total evaluation
    CountersUpgradeable.Counter private _totalEvaluation;

    // Evaluation fee
    // uint256 public evaluationFee;

    // // Minting fee
    // uint256 public mintingFee;

    // White list evaluation fee
    // Address evaluation fee => fee
    mapping(address => uint256) whiteListEvaluationFee;

    // White list minting fee
    // Address minting fee => fee
    mapping(address => uint256) whiteListMintingFee;

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

    // mapping(address => mapping(uint256 => Evaluation))
    //     public evaluation1155WithTokenId;

    // Mapping evaluation list
    // Evaluation id => list evaluation
    mapping(uint256 => Evaluation) public evaluationList;

    // Mapping list evaluation of asset
    // Asset id => list evaluation id;
    mapping(uint256 => uint256[]) public evaluationListOfAsset;

    // Mapping asset 721 of token id
    // Token id => asset 721
    //  mapping(uint256 => Asset) public asset721OfTokenId;

    // Mapping evaluation 721 of token id
    // Token id => evaluation 721
    //  mapping(uint256 => Evaluation) public evaluation721OfTokenId;

    // Mapping asset 1155 of token id
    // Token id => asset 1155
    // mapping(uint256 => Asset) public asset1155OfTokenId;

    // Mapping evaluation 1155 of token id
    // Token id => evaluation 1155
    //  mapping(uint256 => Evaluation) public evaluation1155OfTokenId;

    modifier onlyRoleEvaluator() {
        require(
            IAccessControlUpgradeable(hubContract).hasRole(
                HubRoleLib.EVALUATOR_ROLE,
                msg.sender
            ),
            "0"
        );
        _;
    }

    modifier onlyAdmin() {
        require(
            IAccessControlUpgradeable(hubContract).hasRole(
                HubRoleLib.OPERATOR_ROLE,
                msg.sender
            ),
            "is not admin"
        );
        _;
    }

    function add(uint256 a, uint256 b)
        external
        onlyRoleEvaluator
        returns (uint256)
    {
        return a + b;
    }

    function initialize(address _hubContract) public initializer {
        __Pausable_init();

        //   _setAdminAddress(msg.sender);

        __BaseContract_init(_hubContract);

        hubContract = _hubContract;
    }

    function signature() public pure override returns (bytes4) {
        return type(IDFY_Hard_Evaluation).interfaceId;
    }

    function RegistrywithHubContract() external {
        HubInterface(hubContract).registerContract(signature(), address(this));
    }

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

    function _setAdminAddress() internal {
        // require(!_newAdminAddress.isContract(), "1"); // Address admin is contract
        // require(_newAdminAddress != address(0), "2"); // Address admin not address 0
        (adminAdress, ) = HubInterface(hubContract).getSystemConfig();
    }

    function setAdminAddress() external override onlyRoleAdmin {
        _setAdminAddress();
    }

    function _addWhiteListEvaluationFee(
        address _newAddressEvaluatonFee,
        uint256 _newEvaluationFee
    ) internal {
        if (_newAddressEvaluatonFee != address(0)) {
            require(_newAddressEvaluatonFee.isContract(), "3"); // Address evaluation fee is contract
        }

        require(_newEvaluationFee > 0, "4"); // Evaluation fee than more 0

        whiteListEvaluationFee[_newAddressEvaluatonFee] = _newEvaluationFee;
    }

    function _addWhiteListMintingFee(
        address _newAddressMintingFee,
        uint256 _newMintingFee
    ) internal {
        if (_newAddressMintingFee != address(0)) {
            require(_newAddressMintingFee.isContract(), "5"); // Address minting fee is contract
        }

        require(_newMintingFee > 0, "6"); // Minting fee than more 0

        whiteListMintingFee[_newAddressMintingFee] = _newMintingFee;
    }

    function addWhiteListEvaluationFee(
        address _newAddressEvaluatonFee,
        uint256 _newEvaluationFee
    ) external override onlyRoleAdmin {
        _addWhiteListEvaluationFee(_newAddressEvaluatonFee, _newEvaluationFee);
    }

    function addWhiteListMintingFee(
        address _newAddressMintingFee,
        uint256 _newMintingFee
    ) external override onlyRoleAdmin {
        _addWhiteListMintingFee(_newAddressMintingFee, _newMintingFee);
    }

    function getEvaluationWithTokenId(
        address addressCollection,
        uint256 tokenId
    )
        external
        view
        override
        returns (
            address _currency,
            uint256 _price,
            uint256 _depreciationRate,
            CollectionStandard _collectionStandard
        )
    {
        _currency = evaluationWithTokenId[addressCollection][tokenId].currency;

        _price = evaluationWithTokenId[addressCollection][tokenId].price;

        _depreciationRate = evaluationWithTokenId[addressCollection][tokenId]
            .depreciationRate;

        _collectionStandard = evaluationWithTokenId[addressCollection][tokenId]
            .collectionStandard;
    }

    function createAssetRequest(
        string memory _assetCID,
        address _collectionAsset,
        CollectionStandard _collectionStandard
    ) external override whenNotPaused {
        // Require asset CID
        require(bytes(_assetCID).length > 0, "7"); // Asset CID is Blank

        if (_collectionStandard == CollectionStandard.NFT_HARD_721) {
            require(
                _collectionAsset.supportsInterface(
                    type(IDFY_Hard_721).interfaceId
                ),
                ""
            ); // Invalid Collection
        } else {
            require(
                _collectionAsset.supportsInterface(
                    type(IDFY_Hard_1155).interfaceId
                ),
                ""
            ); // Invalid Collection
        }

        // Create asset id
        uint256 _assetId = _totalAssets.current();

        // Add asset from asset list
        assetList[_assetId] = Asset({
            assetCID: _assetCID,
            owner: msg.sender,
            collectionAddress: _collectionAsset,
            collectionStandard: _collectionStandard,
            status: AssetStatus.OPEN
        });

        // Update total asset
        _totalAssets.increment();

        emit AssetEvent(_assetId, assetList[_assetId]);
    }

    function createAppointment(
        uint256 _assetId,
        address _evaluator,
        address _evaluationFeeAddress
    ) external override whenNotPaused {
        // Get asset by asset id
        Asset storage _asset = assetList[_assetId];

        require(
            bytes(_asset.assetCID).length > 0 &&
                _asset.status == AssetStatus.OPEN &&
                msg.sender == _asset.owner,
            "9"
        ); // Invalid asset

        require(!_evaluator.isContract() && _evaluator != _asset.owner, "11"); // Invalid evaluator

        // Gennerate total appointment
        uint256 _appointmentId = _totalAppointment.current();

        // Add appointment to list appointment
        appointmentList[_appointmentId] = Appointment({
            assetId: _assetId,
            assetOwner: _asset.owner,
            evaluator: _evaluator,
            evaluationFee: whiteListEvaluationFee[_evaluationFeeAddress],
            evaluationFeeAddress: _evaluationFeeAddress,
            status: AppointmentStatus.OPEN
        });

        // Add appointment id to appointment list of asset
        appointmentListOfAsset[_assetId].push(_appointmentId);

        // update status asset
        _asset.status = AssetStatus.APPOINTMENTED;

        Hard_Evaluation_Lib.safeTransfer(
            _evaluationFeeAddress,
            msg.sender,
            address(this),
            whiteListEvaluationFee[_evaluationFeeAddress]
        );

        // Update total appoinment
        _totalAppointment.increment();

        // Send event
        emit AppointmentEvent(
            _appointmentId,
            _asset,
            appointmentList[_appointmentId],
            ""
        );
    }

    function acceptAppointment(uint256 _appointmentId)
        external
        override
        onlyRoleEvaluator
        whenNotPaused
    {
        Appointment storage _appointment = appointmentList[_appointmentId];

        require(
            _appointment.status == AppointmentStatus.OPEN &&
                _appointment.evaluator == msg.sender,
            "12"
        ); // Invalid appoinment

        _appointment.status = AppointmentStatus.ACCEPTED;

        emit AppointmentEvent(
            _appointmentId,
            assetList[_appointment.assetId],
            _appointment,
            ""
        );
    }

    function rejectAppointment(uint256 _appointmentId, string memory reason)
        external
        override
        onlyRoleEvaluator
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

        Hard_Evaluation_Lib.safeTransfer(
            _appointment.evaluationFeeAddress,
            address(this),
            _appointment.assetOwner,
            _appointment.evaluationFee
        );

        emit AppointmentEvent(
            _appointmentId,
            assetList[_appointment.assetId],
            _appointment,
            reason
        );
    }

    function cancelAppointment(uint256 _appointmentId, string memory reason)
        external
        override
    {
        Appointment storage _appointment = appointmentList[_appointmentId];

        require(
            _appointment.status != AppointmentStatus.EVALUATED &&
                _appointment.status != AppointmentStatus.CANCELLED,
            "13"
        ); // Invalid appoinment

        _appointment.status = AppointmentStatus.CANCELLED;

        Asset storage _asset = assetList[_appointment.assetId];

        _asset.status = AssetStatus.OPEN;

        Hard_Evaluation_Lib.safeTransfer(
            _appointment.evaluationFeeAddress,
            address(this),
            _appointment.assetOwner,
            _appointment.evaluationFee
        );

        emit AppointmentEvent(
            _appointmentId,
            assetList[_appointment.assetId],
            _appointment,
            reason
        );
    }

    function evaluatedAsset(
        address _currency,
        uint256 _appointmentId,
        uint256 _price,
        string memory _evaluationCID,
        uint256 _depreciationRate,
        address _mintingFeeAddress
    ) external override onlyRoleEvaluator whenNotPaused {
        Appointment storage _appointment = appointmentList[_appointmentId];

        require(
            _appointment.status == AppointmentStatus.ACCEPTED &&
                _appointment.evaluator == msg.sender,
            "14"
        ); // Invalid appoinment

        Asset storage _asset = assetList[_appointment.assetId];

        require(
            _asset.status == AssetStatus.APPOINTMENTED &&
                _asset.owner != msg.sender,
            "15"
        ); // Invalid asset

        if (_currency != address(0)) {
            require(_currency.isContract(), "16"); // Invalid currency
        }

        require(
            bytes(_evaluationCID).length > 0 &&
                _price > 0 &&
                _depreciationRate > 0,
            "17"
        ); // Invalid evaluation

        // Gennerate evaluation id
        uint256 _evaluationId = _totalEvaluation.current();

        evaluationList[_evaluationId] = Evaluation({
            assetId: _appointment.assetId,
            appointmentId: _appointmentId,
            evaluationCID: _evaluationCID,
            depreciationRate: _depreciationRate,
            evaluator: msg.sender,
            currency: _currency,
            price: _price,
            mintingFee: whiteListMintingFee[_mintingFeeAddress],
            mintingFeeAddress: _mintingFeeAddress,
            collectionAddress: _asset.collectionAddress,
            collectionStandard: _asset.collectionStandard,
            status: EvaluationStatus.EVALUATED
        });

        _appointment.status = AppointmentStatus.EVALUATED;

        Hard_Evaluation_Lib.safeTransfer(
            _appointment.evaluationFeeAddress,
            address(this),
            msg.sender,
            _appointment.evaluationFee
        );

        _totalEvaluation.increment();

        emit EvaluationEvent(
            _evaluationId,
            _asset,
            evaluationList[_evaluationId],
            ""
        );
    }

    function acceptEvaluation(uint256 _evaluationId)
        external
        override
        whenNotPaused
    {
        Evaluation storage _evaluation = evaluationList[_evaluationId];

        require(
            bytes(_evaluation.evaluationCID).length > 0 &&
                _evaluation.status == EvaluationStatus.EVALUATED,
            "18"
        ); // Invalid evaluation

        Asset storage _asset = assetList[_evaluation.assetId];

        require(
            bytes(_asset.assetCID).length > 0 &&
                _asset.status == AssetStatus.APPOINTMENTED &&
                _asset.owner == msg.sender,
            "19"
        ); // Invalid asset

        _evaluation.status = EvaluationStatus.EVALUATION_ACCEPTED;

        for (
            uint256 i = 0;
            i < evaluationListOfAsset[_evaluation.assetId].length;
            i++
        ) {
            if (
                evaluationListOfAsset[_evaluation.assetId][i] != _evaluationId
            ) {
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

        Hard_Evaluation_Lib.safeTransfer(
            _evaluation.mintingFeeAddress,
            msg.sender,
            address(this),
            _evaluation.mintingFee
        );

        emit EvaluationEvent(_evaluationId, _asset, _evaluation, "");
    }

    function rejectEvaluation(uint256 _evaluationId, string memory reason)
        external
        override
        whenNotPaused
    {
        Evaluation storage _evaluation = evaluationList[_evaluationId];

        require(
            bytes(_evaluation.evaluationCID).length > 0 &&
                _evaluation.status == EvaluationStatus.EVALUATED,
            "20"
        ); // Invalid evaluation

        Asset storage _asset = assetList[_evaluation.assetId];

        require(
            bytes(_asset.assetCID).length > 0 &&
                _asset.status == AssetStatus.APPOINTMENTED &&
                _asset.owner == msg.sender,
            "21"
        ); // Invalid asset

        // Update status evaluation
        _evaluation.status = EvaluationStatus.EVALUATION_REJECTED;

        _asset.status = AssetStatus.OPEN;

        emit EvaluationEvent(_evaluationId, _asset, _evaluation, reason);
    }

    function createNftToken(
        uint256 _evaluationId,
        uint256 _amount,
        string memory _nftCID
    ) external override onlyRoleEvaluator whenNotPaused {
        require(bytes(_nftCID).length > 0, "22"); // Invalid nftCID

        Evaluation storage _evaluation = evaluationList[_evaluationId];

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
            tokenId = IDFY_Hard_721(_asset.collectionAddress).mint(
                _asset.owner,
                _nftCID,
                _evaluation.depreciationRate
            );
        } else {
            tokenId = IDFY_Hard_1155(_asset.collectionAddress).mint(
                _asset.owner,
                _amount,
                _nftCID,
                "",
                _evaluation.depreciationRate
            );
        }

        Hard_Evaluation_Lib.safeTransfer(
            _evaluation.mintingFeeAddress,
            address(this),
            adminAdress,
            _evaluation.mintingFee
        );

        _asset.status = AssetStatus.NFT_CREATED;

        _evaluation.status = EvaluationStatus.NFT_CREATED;

        evaluationWithTokenId[_evaluation.collectionAddress][
            tokenId
        ] = _evaluation;

        // if (_asset.collectionStandard == CollectionStandard.NFT_HARD_721) {
        //     // asset721OfTokenId[tokenId] = _asset;
        //     // evaluation721OfTokenId[tokenId] = _evaluation;
        //     evaluation721WithTokenId[_evaluation.collectionAddress][
        //         tokenId
        //     ] = _evaluation;
        // } else {
        //     // asset1155OfTokenId[tokenId] = _asset;
        //     // evaluation1155OfTokenId[tokenId] = _evaluation;
        //     evaluation1155WithTokenId[_evaluation.collectionAddress][
        //         tokenId
        //     ] = _evaluation;
        // }

        emit NFTEvent(tokenId, _nftCID, _amount, _asset, _evaluation);
    }
}
