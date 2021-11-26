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
import "../interface/IDFY_Hard_Evaluation.sol";
import "../interface/IDFY_721.sol";
import "../interface/IDFY_1155.sol";
import "./Hard_Evaluation_Lib.sol";

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
    using ERC165CheckerUpgradeable for address;

    // Admin address
    address private adminAdress;
    
    // Total asset
    CountersUpgradeable.Counter public totalAssets;

    // Total appointment
    CountersUpgradeable.Counter public totalAppointment;

    // Total evaluation
    CountersUpgradeable.Counter public totalEvaluation;

    // Base URI token
    string public baseUri;

    // Evaluation fee
    uint256 public evaluationFee;

    // Minting fee
    uint256 public mintingFee;

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

    // Mapping evaluation list
    // Evaluation id => list evaluation
    mapping(uint256 => Evaluation) public evaluationList;

    // Mapping list evaluation of asset
    // Asset id => list evaluation id;
    mapping(uint256 => uint256[]) public evaluationListOfAsset;

    // Mapping asset of token id
    // Token id => asset
    mapping(uint256 => Asset) public assetOfTokenId;

    // Mapping evaluation of token id
    // Token id => evaluation
    mapping(uint256 => Evaluation) public evaluationOfTokenId;

    modifier onlyRoleAdmin(){
        // todo call hub check role admin
        _;
    }

    modifier onlyRoleEvaluator(){
        // todo call hub check role evaluator
        _;
    }

    function initialize(string memory _uri)
        public
        initializer
    {
        __Pausable_init();

        _setBaseURI(_uri);

        _setAdminAddress(msg.sender);
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

    function _setBaseURI(string memory _newURI)
        internal
    {
        require(bytes(_newURI).length > 0 , '0'); // New URI is blank
        baseUri = _newURI;
    }

    function setBaseURI(string memory _newURI)
        external
        override
        onlyRoleAdmin
    {
        _setBaseURI(_newURI);
    }

    function _setAdminAddress(address _newAdminAddress)
        internal
    {
        require(!_newAdminAddress.isContract(), '1'); // Address admin is contract
        require(_newAdminAddress != address(0), '2'); // Address admin not address 0
        adminAdress = _newAdminAddress;
    }

    function setAdminAddress(address _newAdminAddress)
        external
        override
        onlyRoleAdmin
    {
        _setAdminAddress(_newAdminAddress);
    }

    function _addWhiteListEvaluationFee(
        address _newAddressEvaluatonFee,
        uint256 _newEvaluationFee
    ) 
        internal
    {
        if(_newAddressEvaluatonFee != address(0)){
            require(_newAddressEvaluatonFee.isContract(), '3'); // Address evaluation fee is contract
        }

        require(_newEvaluationFee > 0, '4'); // Evaluation fee than more 0

        whiteListEvaluationFee[_newAddressEvaluatonFee] = _newEvaluationFee;
    }

    function _addWhiteListMintingFee(
        address _newAddressMintingFee,
        uint256 _newMintingFee
    ) 
        internal
    {
        if(_newAddressMintingFee != address(0)){
            require(_newAddressMintingFee.isContract(), '5'); // Address minting fee is contract
        }

        require(_newMintingFee > 0, '6'); // Minting fee than more 0

        whiteListMintingFee[_newAddressMintingFee] = _newMintingFee;
    }

    function addWhiteListEvaluationFee(
        address _newAddressEvaluatonFee,
        uint256 _newEvaluationFee
    ) 
        external
        override
        onlyRoleAdmin
    {
        _addWhiteListEvaluationFee(_newAddressEvaluatonFee, _newEvaluationFee);
    }

    function addWhiteListMintingFee(
        address _newAddressMintingFee,
        uint256 _newMintingFee
    ) 
        external
        override
        onlyRoleAdmin
    {
        _addWhiteListMintingFee(_newAddressMintingFee, _newMintingFee);
    }

    function pause() external onlyRoleAdmin {
        _pause();
    }

    function unpause() external onlyRoleAdmin {
        _unpause();
    }

    function createAssetRequest(
        string memory _assetCID,
        address _collectionAsset,
        uint256 _amount,
        CollectionStandard _collectionStandard
    ) 
        external
        override
        whenNotPaused
    {
        // Require asset CID
        require(bytes(_assetCID).length > 0, "7"); // Asset CID is Blank

        uint256 _amountAsset = 0;

        if (_collectionStandard == CollectionStandard.NFT_HARD_721) {

            // Require collection asset
            if (_collectionAsset.supportsInterface(type(IDFY_721).interfaceId)) {
                _amountAsset = 1;
            }else{
                revert('8'); // Invalid collection
            }
        } else {
             // Require collection asset
            if (_collectionAsset.supportsInterface(type(IDFY_1155).interfaceId)) {
                _amountAsset = _amount;
            }else{
                revert('8'); // Invalid collection
            }
        }

        // Create asset id
        uint256 _assetId = totalAssets.current();

        // Add asset from asset list
        assetList[_assetId] = Asset({
            assetCID: _assetCID,
            owner: msg.sender,
            collectionAddress: _collectionAsset,
            amount: _amountAsset,
            collectionStandard: _collectionStandard,
            status: AssetStatus.OPEN
        });

        // Update total asset
        totalAssets.increment();

        emit AssetEvent(_assetId, assetList[_assetId]);
    }

    function createAppointment(
        uint256 _assetId,
        address _evaluator,
        address _evaluationFeeAddress
    ) 
        external
        override
        whenNotPaused
    {
        // Get asset by asset id
        Asset storage _asset = assetList[_assetId];

        require(
            bytes(_asset.assetCID).length > 0 
            && _asset.status == AssetStatus.OPEN 
            && msg.sender == _asset.owner, '9'
        ); // Invalid asset

        require(!_evaluator.isContract() && _evaluator != _asset.owner, '11'); // Invalid evaluator

        // Gennerate total appointment
        uint256 _appointmentId = totalAppointment.current();

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

        Hard_Evaluation_Lib.safeTransfer(_evaluationFeeAddress, msg.sender, address(this), whiteListEvaluationFee[_evaluationFeeAddress]);

        // Update total asset
        totalAssets.increment();

        // Send event
        emit AppointmentEvent(_appointmentId, _asset, appointmentList[_appointmentId], '');
    }

    function acceptAppointment(
        uint256 _appointmentId
    ) 
        external
        override
        onlyRoleEvaluator
        whenNotPaused
    {
        Appointment storage _appointment = appointmentList[_appointmentId];

        require(
            _appointment.status == AppointmentStatus.OPEN
            && _appointment.evaluator == msg.sender, '12');// Invalid appoinment

        _appointment.status = AppointmentStatus.ACCEPTED;

        emit AppointmentEvent(_appointmentId, assetList[_appointment.assetId], _appointment, '');
    }

    function rejectAppointment(
        uint256 _appointmentId,
        string memory reason
    ) 
        external
        override
        onlyRoleEvaluator
        whenNotPaused
    {
        Appointment storage _appointment = appointmentList[_appointmentId];

        require(
            _appointment.status == AppointmentStatus.OPEN
            && _appointment.evaluator == msg.sender, '13');// Invalid appoinment

        _appointment.status = AppointmentStatus.REJECTED;

        Asset storage _asset = assetList[_appointment.assetId];

        _asset.status = AssetStatus.OPEN;

        Hard_Evaluation_Lib.safeTransfer(_appointment.evaluationFeeAddress, address(this), _appointment.assetOwner, _appointment.evaluationFee);

        emit AppointmentEvent(_appointmentId, assetList[_appointment.assetId], _appointment, reason);
    }

    function cancelAppointment(
        uint256 _appointmentId,
        string memory reason
    ) 
        external
        override
    {
        Appointment storage _appointment = appointmentList[_appointmentId];

        require(
            _appointment.status != AppointmentStatus.EVALUATED
            && _appointment.status != AppointmentStatus.CANCELLED
            && _appointment.evaluator == msg.sender, '13');// Invalid appoinment

        _appointment.status = AppointmentStatus.CANCELLED;

        Asset storage _asset = assetList[_appointment.assetId];

        _asset.status = AssetStatus.OPEN;

        Hard_Evaluation_Lib.safeTransfer(_appointment.evaluationFeeAddress, address(this), _appointment.assetOwner, _appointment.evaluationFee);

        emit AppointmentEvent(_appointmentId, assetList[_appointment.assetId], _appointment, reason);
    }

    function evaluatedAsset(
        address _currency,
        uint256 _appointmentId,
        uint256 _price,
        string memory _evaluationCID,
        uint256 _depreciationRate,
        address _mintingFeeAddress
    ) 
        external
        override
        onlyRoleEvaluator
        whenNotPaused
    {
        Appointment storage _appointment = appointmentList[_appointmentId];

        Asset storage _asset = assetList[_appointment.assetId];

        require(
            _appointment.status == AppointmentStatus.ACCEPTED
            && _appointment.evaluator == msg.sender, '14');// Invalid appoinment

        require(
            _asset.status == AssetStatus.APPOINTMENTED
            && _asset.owner != msg.sender, '15'); // Invalid asset

        if (_currency != address(0)) {
            require(_currency.isContract(), '16'); // Invalid currency
        }

        require (
            bytes(_evaluationCID).length > 0
            && _price > 0
            && _depreciationRate > 0, '17'
            ); // Invalid evaluation
        

        // Gennerate evaluation id
        uint256 _evaluationId = totalEvaluation.current();

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

        Hard_Evaluation_Lib.safeTransfer(_appointment.evaluationFeeAddress, address(this), msg.sender, _appointment.evaluationFee);

        totalEvaluation.increment();

        emit EvaluationEvent(_evaluationId, _asset, evaluationList[_evaluationId], '');

    }

    function acceptEvaluation(
        uint256 _evaluationId
    ) 
        external
        override
        whenNotPaused
    {

        Evaluation storage _evaluation = evaluationList[_evaluationId];

        require(
            bytes(_evaluation.evaluationCID).length > 0
            && _evaluation.status == EvaluationStatus.EVALUATED, '18'
        ); // Invalid evaluation

        
        Asset storage _asset = assetList[_evaluation.assetId];

        require(
            bytes(_asset.assetCID).length > 0 
            && _asset.status == AssetStatus.APPOINTMENTED
            && _asset.owner == msg.sender, '19'
        ); // Invalid asset
 
        _evaluation.status = EvaluationStatus.EVALUATION_ACCEPTED;

        for (uint256 i = 0; i < evaluationListOfAsset[_evaluation.assetId].length; i++) {
            if (evaluationListOfAsset[_evaluation.assetId][i] != _evaluationId) {

                uint256 _evaluationIdReject = evaluationListOfAsset[_evaluation.assetId][i];

                Evaluation storage _evaluationReject = evaluationList[_evaluationIdReject];

                if( _evaluationReject.status != EvaluationStatus.EVALUATION_REJECTED){
                    _evaluationReject.status = EvaluationStatus.EVALUATION_REJECTED;

                    emit EvaluationEvent(
                        _evaluationIdReject,
                        _asset,
                        _evaluationReject,
                        ''
                    );
                }    
            }
        }

        _asset.status = AssetStatus.EVALUATED;


        Hard_Evaluation_Lib.safeTransfer(_evaluation.mintingFeeAddress, msg.sender, address(this), _evaluation.mintingFee);

        emit EvaluationEvent(_evaluationId, _asset, _evaluation, '');
    }

    function rejectEvaluation(
        uint256 _evaluationId,
        string memory reason
    ) 
        external
        override
        whenNotPaused
    {
        Evaluation storage _evaluation = evaluationList[_evaluationId];

        require(
            bytes(_evaluation.evaluationCID).length > 0
            && _evaluation.status == EvaluationStatus.EVALUATED, '20'
        ); // Invalid evaluation

        
        Asset storage _asset = assetList[_evaluation.assetId];

        require(
            bytes(_asset.assetCID).length > 0 
            && _asset.status == AssetStatus.APPOINTMENTED
            && _asset.owner == msg.sender, '21'
        ); // Invalid asset

        // Update status evaluation
        _evaluation.status = EvaluationStatus.EVALUATION_REJECTED;

        _asset.status = AssetStatus.OPEN;

        emit EvaluationEvent(_evaluationId, _asset, _evaluation, reason);
    }

    function createNftToken(
        uint256 _evaluationId,
        string memory _nftCID
    ) 
        external
        override
        onlyRoleEvaluator
        whenNotPaused
    {
        require(bytes(_nftCID).length > 0, '22'); // Invalid nftCID

        Evaluation storage _evaluation = evaluationList[_evaluationId];

        require(
            bytes(_evaluation.evaluationCID).length > 0
            && _evaluation.status == EvaluationStatus.EVALUATION_ACCEPTED
            && _evaluation.evaluator == msg.sender, '23'
        ); // Invalid evaluation

        Asset storage _asset = assetList[_evaluation.assetId];

        require(
            bytes(_asset.assetCID).length > 0 
            && _asset.status == AssetStatus.EVALUATED, '21'
        ); // Invalid asset

        uint256 tokenId;

        if (_asset.collectionStandard == CollectionStandard.NFT_HARD_721) {
            tokenId = IDFY_721(_asset.collectionAddress).mint(
                _asset.owner,
                _nftCID,
                _evaluation.depreciationRate
            );
        } else {
            tokenId = IDFY_1155(_asset.collectionAddress).mint(
                _asset.owner,
                _asset.amount,
                _nftCID,
                "",
                _evaluation.depreciationRate
            );
        }

        Hard_Evaluation_Lib.safeTransfer(_evaluation.mintingFeeAddress, address(this), adminAdress, _evaluation.mintingFee);

        _asset.status = AssetStatus.NFT_CREATED;

        _evaluation.status = EvaluationStatus.NFT_CREATED;

        assetOfTokenId[tokenId] = _asset;

        evaluationOfTokenId[tokenId] = _evaluation;

        emit NFTEvent(tokenId, _nftCID, _asset, _evaluation);
    }
}