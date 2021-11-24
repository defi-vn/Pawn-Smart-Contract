// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
// import "../access/DFY-AccessControl.sol";
import "./HubInterface.sol";
import "./HubLib.sol";

contract Hub is
    Initializable,
    UUPSUpgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    HubInterface
{
    using AddressUpgradeable for address;

    mapping(bytes4 => address) public ContractRegistry;

    SystemConfig public systemConfig;
    PawnConfig public pawnConfig;
    PawnNFTConfig public pawnNFTConfig;

    // TODO: New state variables must go below this line -----------------------------

    /** ==================== Contract initializing & configuration ==================== */
    function initialize(
        address feeWallet,
        address feeToken,
        address operator
    ) public initializer {
        __UUPSUpgradeable_init();
        __Pausable_init();
        __AccessControl_init();
        systemConfig.systemFeeWallet = feeWallet;
        systemConfig.systemFeeToken = feeToken;
        // systemConfig.Admin = msg.sender;
        // systemConfig.Admin = operator;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(HubRoleLib.DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(HubRoleLib.OPERATOR_ROLE, operator);
        _setupRole(HubRoleLib.PAUSER_ROLE, msg.sender);
        _setupRole(HubRoleLib.EVALUATOR_ROLE, msg.sender);
    }

    function setOperator(address _newOperator)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        // operator = _newOperator;

        grantRole(HubRoleLib.OPERATOR_ROLE, _newOperator);
    }

    function setPauseRole(address _newPauseRole)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        grantRole(HubRoleLib.PAUSER_ROLE, _newPauseRole);
    }

    function setEvaluationRole(address _newEvaluationRole) external {
        grantRole(HubRoleLib.EVALUATOR_ROLE, _newEvaluationRole);
    }

    modifier whenContractNotPaused() {
        _whenNotPaused();
        _;
    }

    function _whenNotPaused() private view {
        require(!paused(), "Pausable: paused");
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unPause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    /** ==================== Hub operation functions ==================== */

    function setSystemConfig(address _FeeWallet, address _FeeToken)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (_FeeWallet != address(0)) {
            systemConfig.systemFeeWallet = _FeeWallet;
        }

        if (_FeeToken != address(0)) {
            systemConfig.systemFeeToken = _FeeToken;
        }
    }

    function getSystemConfig()
        external
        view
        override
        returns (address _FeeWallet, address _FeeToken)
    {
        _FeeWallet = systemConfig.systemFeeWallet;
        _FeeToken = systemConfig.systemFeeToken;
    }

    function registerContract(bytes4 nameContract, address contractAddress)
        external
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        ContractRegistry[nameContract] = contractAddress;
    }

    function getContractAddress(bytes4 _nameContract)
        external
        view
        override
        returns (address _contractAddres)
    {
        _contractAddres = ContractRegistry[_nameContract];
    }

    /** ==================== Standard interface function implementations ==================== */

    function _authorizeUpgrade(address)
        internal
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {}

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /** ================= config PAWN NFT ============== */
    function setEvaluationContract(address _evaluationContract, uint256 _status)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        pawnNFTConfig.whitelistedEvaluationContract[
            _evaluationContract
        ] = _status;
    }

    function getEvaluationContract(address _evaluationContractAddress)
        external
        view
        override
        returns (uint256 _status)
    {
        _status = pawnNFTConfig.whitelistedEvaluationContract[
            _evaluationContractAddress
        ];
    }

    function setWhitelistCollateral_NFT(address _token, uint256 _status)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        pawnNFTConfig.whitelistedCollateral[_token] = _status;
    }

    function getWhitelistCollateral_NFT(address _token)
        external
        view
        override
        returns (uint256 _status)
    {
        _status = pawnNFTConfig.whitelistedCollateral[_token];
    }

    function setPawnNFTConfig(
        int256 _zoom,
        int256 _FeeRate,
        int256 _penaltyRate,
        int256 _prepaidFeedRate,
        int256 _lateThreshold
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_zoom >= 0) {
            pawnNFTConfig.ZOOM = abs(_zoom);
        }

        if (_FeeRate >= 0) {
            pawnNFTConfig.systemFeeRate = abs(_FeeRate);
        }

        if (_penaltyRate >= 0) {
            pawnNFTConfig.penaltyRate = abs(_penaltyRate);
        }

        if (_prepaidFeedRate >= 0) {
            pawnNFTConfig.prepaidFeeRate = abs(_prepaidFeedRate);
        }

        if (_lateThreshold >= 0) {
            pawnNFTConfig.lateThreshold = abs(_lateThreshold);
        }
    }

    function getPawnNFTConfig()
        external
        view
        override
        returns (
            uint256 _zoom,
            uint256 _FeeRate,
            uint256 _penaltyRate,
            uint256 _prepaidFeedRate,
            uint256 _lateThreshold
        )
    {
        _zoom = pawnNFTConfig.ZOOM;
        _FeeRate = pawnNFTConfig.systemFeeRate;
        _penaltyRate = pawnNFTConfig.penaltyRate;
        _prepaidFeedRate = pawnNFTConfig.prepaidFeeRate;
        _lateThreshold = pawnNFTConfig.lateThreshold;
    }

    /** ========== ConFIg PAWN crypto ===================*/

    function setWhitelistCollateral(address _token, uint256 _status)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        pawnConfig.whitelistedCollateral[_token] = _status;
    }

    function getWhitelistCollateral(address _token)
        external
        view
        override
        returns (uint256 _status)
    {
        _status = pawnConfig.whitelistedCollateral[_token];
    }

    function setPawnConfig(
        int256 _zoom,
        int256 _FeeRate,
        int256 _penaltyRate,
        int256 _prepaidFeedRate,
        int256 _lateThreshold
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_zoom >= 0) {
            pawnNFTConfig.ZOOM = abs(_zoom);
        }

        if (_FeeRate >= 0) {
            pawnNFTConfig.systemFeeRate = abs(_FeeRate);
        }

        if (_penaltyRate >= 0) {
            pawnNFTConfig.penaltyRate = abs(_penaltyRate);
        }

        if (_prepaidFeedRate >= 0) {
            pawnNFTConfig.prepaidFeeRate = abs(_prepaidFeedRate);
        }

        if (_lateThreshold >= 0) {
            pawnNFTConfig.lateThreshold = abs(_lateThreshold);
        }
    }

    function getPawnConfig()
        external
        view
        override
        returns (
            uint256 _zoom,
            uint256 _FeeRate,
            uint256 _penaltyRate,
            uint256 _prepaidFeeRate,
            uint256 _lateThreshold
        )
    {
        _zoom = pawnConfig.ZOOM;
        _FeeRate = pawnConfig.systemFeeRate;
        _penaltyRate = pawnConfig.penaltyRate;
        _prepaidFeeRate = pawnConfig.prepaidFeeRate;
        _lateThreshold = pawnConfig.lateThreshold;
    }

    /**======================= */

    function abs(int256 _input) internal pure returns (uint256) {
        return _input >= 0 ? uint256(_input) : uint256(_input * -1);
    }
}
