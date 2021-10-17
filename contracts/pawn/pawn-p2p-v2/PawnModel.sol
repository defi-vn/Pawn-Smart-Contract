// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "./IPawn.sol";
import "./PawnLib.sol";
import "../exchange/Exchange.sol";
import "../access/DFY-AccessControl.sol";
import "../reputation/IReputation.sol";

abstract contract PawnModel is
    IPawnV2,
    Initializable,
    UUPSUpgradeable,
    DFYAccessControl,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable 
{
    
    /** ==================== Common state variables ==================== */
    
    mapping(address => uint256) public whitelistCollateral;
    address public feeWallet;
    uint256 public lateThreshold;
    uint256 public penaltyRate;
    uint256 public systemFeeRate; 
    uint256 public prepaidFeeRate;
    uint256 public ZOOM;

    IReputation public reputation;

    /** ==================== Collateral related state variables ==================== */
    // uint256 public numberCollaterals;
    // mapping(uint256 => Collateral) public collaterals;

    /** ==================== Common events ==================== */

    event SubmitPawnShopPackage(
        uint256 packageId,
        uint256 collateralId,
        LoanRequestStatus status
    );

    /** ==================== Initialization ==================== */

    /**
    * @dev initialize function
    * @param _zoom is coefficient used to represent risk params
    */
    function __PawnModel_init(uint32 _zoom) internal initializer {
        __PawnModel_init_unchained();

        ZOOM = _zoom;
    }

    function __PawnModel_init_unchained() internal initializer {
        __DFYAccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
    }

    /** ==================== Common functions ==================== */

    // modifier onlyOperator() {
    //     // require(operator == msg.sender, "operator");
    //     _onlyOperator();
    //     _;
    // }
    
    modifier whenContractNotPaused() {
        // require(!paused(), "Pausable: paused");
        _whenNotPaused();
        _;
    }

    // function _onlyOperator() private view {
    //     require(operator == msg.sender, "-0"); //operator
    // }

    function _whenNotPaused() private view {
        require(!paused(), "Pausable: paused");
    }
    
    function pause() onlyRole(DEFAULT_ADMIN_ROLE) external {
        _pause();
    }

    function unPause() onlyRole(DEFAULT_ADMIN_ROLE) external {
        _unpause();
    }

    function setOperator(address _newOperator) onlyRole(DEFAULT_ADMIN_ROLE) external {
        // operator = _newOperator;
        grantRole(OPERATOR_ROLE, _newOperator);
    }

    function setFeeWallet(address _newFeeWallet) onlyRole(DEFAULT_ADMIN_ROLE) external {
        feeWallet = _newFeeWallet;
    }

    /**
    * @dev set fee for each token
    * @param _feeRate is percentage of tokens to pay for the transaction
    */
    function setSystemFeeRate(uint256 _feeRate) external onlyRole(DEFAULT_ADMIN_ROLE) {
        systemFeeRate = _feeRate;
    }

    /**
    * @dev set fee for each token
    * @param _feeRate is percentage of tokens to pay for the penalty
    */
    function setPenaltyRate(uint256 _feeRate) external onlyRole(DEFAULT_ADMIN_ROLE) {
        penaltyRate = _feeRate;
    }

    /**
    * @dev set fee for each token
    * @param _threshold is number of time allowed for late repayment
    */
    function setLateThreshold(uint256 _threshold) external onlyRole(DEFAULT_ADMIN_ROLE) {
        lateThreshold = _threshold;
    }

    function setPrepaidFeeRate(uint256 _feeRate) external onlyRole(DEFAULT_ADMIN_ROLE) {
        prepaidFeeRate = _feeRate;
    }

    function setWhitelistCollateral(address _token, uint256 _status) external onlyRole(DEFAULT_ADMIN_ROLE) {
        whitelistCollateral[_token] = _status;
    }

    function emergencyWithdraw(address _token)
        external
        override
        whenPaused
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        PawnLib.safeTransfer(
            _token,
            address(this),
            _msgSender(),
            PawnLib.calculateAmount(_token, address(this))
        );
    }

    /** ==================== Reputation ==================== */
    
    function setReputationContract(address _reputationAddress)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        reputation = IReputation(_reputationAddress);
    }

    /** ==================== Exchange functions & states ==================== */
    Exchange public exchange;

    function setExchangeContract(address _exchangeAddress) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        exchange = Exchange(_exchangeAddress);
    }

    /** ==================== Standard interface function implementations ==================== */

    function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    function supportsInterface(bytes4 interfaceId) 
        public view 
        override(AccessControlUpgradeable) 
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}