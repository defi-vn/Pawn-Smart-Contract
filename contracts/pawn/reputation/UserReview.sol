// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "../reputation/IReputation.sol";
import "../pawn-p2p/IPawn.sol";
import "../pawn-p2p-v2/ILoan.sol";

contract UserReview is
    Initializable,
    UUPSUpgradeable,
    AccessControlUpgradeable
{
    address public pawnContract;
    address public loanContract;

    IReputation public reputation;

    event UserReviewSubmitted(
        address reviewer,
        address reviewee,
        uint256 points,
        uint256 contractId
    );

    /** ==================== Initialization ==================== */

    /**
    * @dev initialize function
    */
    function __UserReview_init(
        address _pawnContract,
        address _loanContract
    ) internal initializer {
        __UserReview_init_unchained();

        pawnContract = _pawnContract;
        loanContract = _loanContract;
    }

    function __UserReview_init_unchained() internal initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();
    }

    function setReputationContract(address _reputationAddress)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        reputation = IReputation(_reputationAddress);
    }

    function setPawnContract(address _pawnContractAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        pawnContract = _pawnContractAddress;
    }

    function setLoanContract(address _loanContractAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        loanContract = _loanContractAddress;
    }

    /** ==================== User-reviews function implementations ==================== */
    
    function submitReviewPoint(
        address _sender, 
        uint256 _points, 
        uint256 _contractId, 
        address _pawnContractAddress
    ) external 
    {

        // emit UserReviewSubmitted(_sender, reviewee, _points, _contractId);
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