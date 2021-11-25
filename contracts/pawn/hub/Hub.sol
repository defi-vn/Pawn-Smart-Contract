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
import "../libs/CommonLib.sol";
import "./HubLib.sol";
import "./HubInterface.sol";

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
    NFTCollectionConfig public nftCollectionConfig;
    NFTMarketConfig public nftMarketConfig;

    /** ==================== Contract initializing & configuration ==================== */
    function initialize(
        address feeWallet,
        address feeToken,
        address operator
    ) public initializer {
        __UUPSUpgradeable_init();
        __Pausable_init();
        __AccessControl_init();
        
        _setupRole(HubRoleLib.DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(HubRoleLib.OPERATOR_ROLE, operator);
        _setupRole(HubRoleLib.PAUSER_ROLE, msg.sender);
        _setupRole(HubRoleLib.EVALUATOR_ROLE, msg.sender);

        // Set OPERATOR_ROLE as EVALUATOR_ROLE's Admin Role
        _setRoleAdmin(HubRoleLib.EVALUATOR_ROLE, HubRoleLib.OPERATOR_ROLE);

        systemConfig.systemFeeWallet = feeWallet;
        systemConfig.systemFeeToken = feeToken;
    }

    function setOperator(address _newOperator)
        external
        onlyRole(HubRoleLib.DEFAULT_ADMIN_ROLE)
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

    function pause() external onlyRole(HubRoleLib.PAUSER_ROLE) {
        _pause();
    }

    function unPause() external onlyRole(HubRoleLib.PAUSER_ROLE) {
        _unpause();
    }

    function AdminRole() public pure override returns (bytes32) {
        return HubRoleLib.DEFAULT_ADMIN_ROLE;
    }

    function OperatorRole() public pure override returns (bytes32) {
        return HubRoleLib.OPERATOR_ROLE;
    }

    function PauserRole() public pure override returns (bytes32) {
        return HubRoleLib.PAUSER_ROLE;
    }

    function EvaluatorRole() public pure override returns (bytes32) {
        return HubRoleLib.EVALUATOR_ROLE;
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

    /** ==================== Hub operation functions ==================== */
    function registerContract(bytes4 signature, address contractAddress)
        external
        override
        onlyRole(HubRoleLib.DEFAULT_ADMIN_ROLE)
    {
        ContractRegistry[signature] = contractAddress;
    }
    
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

    function getContractAddress(bytes4 signature)
        external
        view
        override
        returns (address contractAddress)
    {
        contractAddress = ContractRegistry[signature];
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
            pawnNFTConfig.ZOOM = CommonLib.abs(_zoom);
        }

        if (_FeeRate >= 0) {
            pawnNFTConfig.systemFeeRate = CommonLib.abs(_FeeRate);
        }

        if (_penaltyRate >= 0) {
            pawnNFTConfig.penaltyRate = CommonLib.abs(_penaltyRate);
        }

        if (_prepaidFeedRate >= 0) {
            pawnNFTConfig.prepaidFeeRate = CommonLib.abs(_prepaidFeedRate);
        }

        if (_lateThreshold >= 0) {
            pawnNFTConfig.lateThreshold = CommonLib.abs(_lateThreshold);
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

    /** =================== ConFIg PAWN crypto ===================*/

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
            pawnNFTConfig.ZOOM = CommonLib.abs(_zoom);
        }

        if (_FeeRate >= 0) {
            pawnNFTConfig.systemFeeRate = CommonLib.abs(_FeeRate);
        }

        if (_penaltyRate >= 0) {
            pawnNFTConfig.penaltyRate = CommonLib.abs(_penaltyRate);
        }

        if (_prepaidFeedRate >= 0) {
            pawnNFTConfig.prepaidFeeRate = CommonLib.abs(_prepaidFeedRate);
        }

        if (_lateThreshold >= 0) {
            pawnNFTConfig.lateThreshold = CommonLib.abs(_lateThreshold);
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

    /** =================== Config NFT Collection & Market ===================*/

    function setNFTConfiguration(
        int256 collectionCreatingFee,
        int256 mintingFee
    ) external onlyRole(HubRoleLib.DEFAULT_ADMIN_ROLE) {
        if (collectionCreatingFee >= 0) {
            nftCollectionConfig.collectionCreatingFee = CommonLib.abs(
                collectionCreatingFee
            );
        }
        if (mintingFee >= 0) {
            nftCollectionConfig.mintingFee = CommonLib.abs(mintingFee);
        }
    }

    function setNFTMarketConfig(
        int256 zoom,
        int256 marketFeeRate,
        address marketFeeWallet
    ) external onlyRole(HubRoleLib.DEFAULT_ADMIN_ROLE) {
        if (zoom >= 0) {
            nftMarketConfig.ZOOM = CommonLib.abs(zoom);
        }
        if (marketFeeRate >= 0) {
            nftMarketConfig.marketFeeRate = CommonLib.abs(marketFeeRate);
        }
        if (marketFeeWallet != address(0) && !marketFeeWallet.isContract()) {
            nftMarketConfig.marketFeeWallet = marketFeeWallet;
        }
    }

    function getNFTCollectionConfig()
        external
        view
        override
        returns (uint256 collectionCreatingFee, uint256 mintingFee)
    {
        collectionCreatingFee = nftCollectionConfig.collectionCreatingFee;
        mintingFee = nftCollectionConfig.mintingFee;
    }

    function getNFTMarketConfig()
        external
        view
        override
        returns (
            uint256 zoom,
            uint256 marketFeeRate,
            address marketFeeWallet
        )
    {
        zoom = nftMarketConfig.ZOOM;
        marketFeeRate = nftMarketConfig.marketFeeRate;
        marketFeeWallet = nftMarketConfig.marketFeeWallet;
    }

    /**======================= */

    event ContractAdminChanged(address from, address to);

    /**
     * @dev change contract's admin to a new address
     */
    function changeContractAdmin(address newAdmin)
        public
        virtual
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        // Check if the new Admin address is a contract address
        require(!newAdmin.isContract(), "New admin must not be a contract");

        grantRole(DEFAULT_ADMIN_ROLE, newAdmin);
        renounceRole(DEFAULT_ADMIN_ROLE, _msgSender());

        emit ContractAdminChanged(_msgSender(), newAdmin);
    }
}
