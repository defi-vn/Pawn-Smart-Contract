// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "../../reputation/IReputation.sol";
import "../../pawn-p2p/IPawn.sol";
import "../../pawn-p2p-v2/ILoan.sol";
import "../../pawn-p2p-v2/PawnLib.sol";
import "../../pawn-nft-v2/IPawnNFT.sol";
import "../../pawn-nft-v2/ILoanNFT.sol";
import "../../pawn-base/IEnums.sol";

contract UserReview is
    Initializable,
    UUPSUpgradeable,
    AccessControlUpgradeable
{
    IReputation public reputation;

    address public pawnContract;
    address public loanContract;

    // mapping from reviewer address to pawn or loan contract address => contractId
    mapping(address => mapping(bytes32 => bool))
        public _listOfContractReviewedByUser;

    mapping(address => mapping(bytes32 => Review)) public _listOfReviewByUser;

    mapping(uint8 => IReputation.ReasonType) public _lenderReviewedByBorrower;
    mapping(uint8 => IReputation.ReasonType) public _borrowerReviewedByLender;

    /// @custom:oz-renamed-from pawnNFTContract
    address public loanNFTContract;

    struct Review {
        address reviewee;
        uint256 contractId;
        uint256 points;
        address contractOrigin;
    }

    event UserReviewSubmitted(
        address reviewer,
        address reviewee,
        uint256 points,
        uint256 contractId,
        address contractOrigin,
        IReputation.ReasonType reason
    );

    /** ==================== Initialization ==================== */

    /**
     * @dev initialize function
     */
    function initialize(
        address _pawnContractAddress,
        address _loanContractAddress,
        address _loanNFTContractAddress,
        address _reputationContractAddress
    ) public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);

        pawnContract = _pawnContractAddress;
        loanContract = _loanContractAddress;
        loanNFTContract = _loanNFTContractAddress;
        reputation = IReputation(_reputationContractAddress);

        _initializePointToRewardReason();
    }

    function setReputationContract(address _reputationContractAddress)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        reputation = IReputation(_reputationContractAddress);
    }

    function setPawnContract(address _pawnContractAddress)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        pawnContract = _pawnContractAddress;
    }

    function setLoanContract(address _loanContractAddress)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        loanContract = _loanContractAddress;
    }

    function setLoanNFTContract(address _loanNFTContractAddress)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        loanNFTContract = _loanNFTContractAddress;
    }

    function initializePointToRewardReason()
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _initializePointToRewardReason();
    }

    function _initializePointToRewardReason() internal virtual {
        _lenderReviewedByBorrower[1] = IReputation
            .ReasonType
            .LD_REVIEWED_BY_BORROWER_1;
        _lenderReviewedByBorrower[2] = IReputation
            .ReasonType
            .LD_REVIEWED_BY_BORROWER_2;
        _lenderReviewedByBorrower[3] = IReputation
            .ReasonType
            .LD_REVIEWED_BY_BORROWER_3;
        _lenderReviewedByBorrower[4] = IReputation
            .ReasonType
            .LD_REVIEWED_BY_BORROWER_4;
        _lenderReviewedByBorrower[5] = IReputation
            .ReasonType
            .LD_REVIEWED_BY_BORROWER_5;

        _borrowerReviewedByLender[1] = IReputation
            .ReasonType
            .BR_REVIEWED_BY_LENDER_1;
        _borrowerReviewedByLender[2] = IReputation
            .ReasonType
            .BR_REVIEWED_BY_LENDER_2;
        _borrowerReviewedByLender[3] = IReputation
            .ReasonType
            .BR_REVIEWED_BY_LENDER_3;
        _borrowerReviewedByLender[4] = IReputation
            .ReasonType
            .BR_REVIEWED_BY_LENDER_4;
        _borrowerReviewedByLender[5] = IReputation
            .ReasonType
            .BR_REVIEWED_BY_LENDER_5;
    }

    /** ==================== User-reviews function implementations ==================== */

    function submitUserReviewCryptoContract(
        uint8 _points,
        uint256 _contractId,
        address _contractAddress
    ) external {
        require(
            _contractAddress == pawnContract ||
                _contractAddress == loanContract,
            "DFY: Invalid pawn or loan contract"
        ); // invalid pawn or loan contract

        address borrower;
        address lender;
        ContractStatus status;

        // Get contract data for review
        if (_contractAddress == pawnContract) {
            (borrower, lender, status) = IPawn(pawnContract)
                .getContractInfoForReview(_contractId);
        } else if (_contractAddress == loanContract) {
            (borrower, lender, status) = ILoan(loanContract)
                .getContractInfoForReview(_contractId);
        }

        // Check contract status, must be Completed or Default
        require(
            (status == ContractStatus.COMPLETED ||
                status == ContractStatus.DEFAULT),
            "DFY: Crypto loan contract is active"
        ); // Loan contract must not active

        _submitUserReview(
            borrower,
            lender,
            _contractId,
            _contractAddress,
            _points
        );
    }

    function submitUserReviewNFTContract(
        uint8 _points,
        uint256 _contractId,
        address _contractAddress
    ) external {
        require(
            _contractAddress == loanNFTContract,
            "DFY: Invalid NFT loan contract"
        ); // invalid Loan NFT contract

        (
            address borrower,
            address lender,
            IEnums.ContractStatus status
        ) = ILoanNFT(loanNFTContract).getContractInfoForReview(_contractId);

        // Check contract status, must be Completed or Default
        require(
            (status == IEnums.ContractStatus.COMPLETED ||
                status == IEnums.ContractStatus.DEFAULT),
            "DFY: NFT loan contract is active"
        ); // Loan contract must not active

        _submitUserReview(
            borrower,
            lender,
            _contractId,
            _contractAddress,
            _points
        );
    }

    function _submitUserReview(
        address _borrower,
        address _lender,
        uint256 _contractId,
        address _contractOrigin,
        uint8 _points
    ) internal {
        // Determine reviewer, reviewee, and reward reason
        address reviewer;
        address reviewee;
        IReputation.ReasonType rewardReason;
        if (msg.sender == _borrower) {
            reviewer = _borrower;
            reviewee = _lender;
            rewardReason = IReputation.ReasonType(
                _lenderReviewedByBorrower[_points]
            );
        } else if (msg.sender == _lender) {
            reviewer = _lender;
            reviewee = _borrower;
            rewardReason = IReputation.ReasonType(
                _borrowerReviewedByLender[_points]
            );
        }

        // Check for invalid reviewer
        require(reviewer != address(0), "DFY: Reviewer is not defined"); // Reviewer is undefined

        // Check if contract has been reviewed by reviewer
        bytes32 key = keccak256(abi.encodePacked(_contractOrigin, _contractId));
        require(
            _listOfContractReviewedByUser[reviewer][key] == false,
            "DFY: Contract must not be reviewed by this user"
        ); // Contract must not be reviewed by this user before

        // Store review information
        _listOfReviewByUser[reviewer][key] = Review(
            reviewee,
            _contractId,
            _points,
            _contractOrigin
        );
        _listOfContractReviewedByUser[reviewer][key] = true;

        // Adjust reputation point of reviewee
        reputation.adjustReputationScore(reviewee, rewardReason);

        emit UserReviewSubmitted(
            reviewer,
            reviewee,
            _points,
            _contractId,
            _contractOrigin,
            rewardReason
        );
    }

    function getReviewKey(uint256 _contractId, address _contractAddress)
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(_contractAddress, _contractId));
    }

    function getContractReviewStatusByUser(
        address _user,
        uint256 _contractId,
        address _contractAddress
    ) external view returns (bool) {
        bytes32 key = keccak256(
            abi.encodePacked(_contractAddress, _contractId)
        );
        address sender = _user != address(0) ? _user : _msgSender();

        return _listOfContractReviewedByUser[sender][key];
    }

    function getContractReviewInfoByUser(
        address _user,
        uint256 _contractId,
        address _contractAddress
    ) external view returns (Review memory) {
        bytes32 key = keccak256(
            abi.encodePacked(_contractAddress, _contractId)
        );
        address sender = _user != address(0) ? _user : _msgSender();

        return _listOfReviewByUser[sender][key];
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
}
