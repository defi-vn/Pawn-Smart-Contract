// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "./PawnModel.sol";
import "../access/DFY-AccessControl.sol";
import "../reputation/IReputation.sol";

contract PawnContractV2 is PawnModel
{
    using CountersUpgradeable for CountersUpgradeable.Counter;
    using AddressUpgradeable for address;
    using SafeMathUpgradeable for uint;
    using CollateralLib for Collateral;
    using OfferLib for Offer;

    mapping(address => bool) whitelistedPawnContract;

    /** ==================== Collateral related state variables ==================== */
    uint256 public numberCollaterals;
    mapping(uint256 => Collateral) public collaterals;

    /** ==================== Offer related state variables ==================== */
    uint256 public numberOffers;
    mapping(uint256 => CollateralOfferList) public collateralOffersMapping;

    /** ==================== Pawshop package related state variables ==================== */
    uint256 public numberPawnShopPackages;
    mapping(uint256 => PawnShopPackage) public pawnShopPackages;
    mapping(uint256 => CollateralAsLoanRequestListStruct) public collateralAsLoanRequestMapping; // Map from collateral to loan request
    
    /** ==================== Collateral related events ==================== */
    event CreateCollateralEvent(
        uint256 collateralId,
        Collateral data
    );

    event WithdrawCollateralEvent(
        uint256 collateralId,
        address collateralOwner
    );

    /** ==================== Offer related events ==================== */
    event CreateOfferEvent(
        uint256 offerId,
        uint256 collateralId,
        Offer data
    );

    event CancelOfferEvent(
        uint256 offerId,
        uint256 collateralId,
        address offerOwner
    );

    /** ==================== Pawshop package related events ==================== */
    event CreatePawnShopPackage(
        uint256 packageId,
        PawnShopPackage data
    );

    event ChangeStatusPawnShopPackage(
        uint256 packageId,
        PawnShopPackageStatus status         
    );


    /** ==================== Initialization ==================== */

    /**
    * @dev initialize function
    * @param _zoom is coefficient used to represent risk params
    */
    function initialize(uint32 _zoom) public initializer {
        __PawnModel_init(_zoom);
    }

    /** ==================== Collateral functions ==================== */
    
    /**
    * @dev create Collateral function, collateral will be stored in this contract
    * @param _collateralAddress is address of collateral
    * @param _packageId is id of pawn shop package
    * @param _amount is amount of token
    * @param _loanAsset is address of loan token
    * @param _expectedDurationQty is expected duration
    * @param _expectedDurationType is expected duration type
    */
    function createCollateral(
        address _collateralAddress,
        int256 _packageId,
        uint256 _amount,
        address _loanAsset,
        uint256 _expectedDurationQty,
        LoanDurationType _expectedDurationType
    ) 
        external 
        payable 
        whenNotPaused 
        returns (uint256 _idx) 
    {
        //check whitelist collateral token
        require(whitelistCollateral[_collateralAddress] == 1, '0'); //n-sup-col
        //validate: cannot use BNB as loanAsset
        require(_loanAsset != address(0), '1'); //bnb

        //id of collateral
        _idx = numberCollaterals;

        //create new collateral
        Collateral storage newCollateral = collaterals[_idx];
        
        newCollateral.create(
            _collateralAddress,
            _amount,
            _loanAsset,
            _expectedDurationQty,
            _expectedDurationType
        );

        ++numberCollaterals;

        emit CreateCollateralEvent(_idx, newCollateral);

        if (_packageId >= 0) {
            //Package must active
            PawnShopPackage storage pawnShopPackage = pawnShopPackages[uint256(_packageId)];
            require(pawnShopPackage.status == PawnShopPackageStatus.ACTIVE, '2'); //pack

            // Submit collateral to package
            CollateralAsLoanRequestListStruct storage loanRequestListStruct = collateralAsLoanRequestMapping[_idx];

            newCollateral.submitToLoanPackage(
                uint256(_packageId),
                loanRequestListStruct
            );

            emit SubmitPawnShopPackage(
                uint256(_packageId),
                _idx,
                LoanRequestStatus.PENDING
            );
        }

        // transfer to this contract
        PawnLib.safeTransfer(
            _collateralAddress,
            msg.sender,
            address(this),
            _amount
        );

        // Adjust reputation score
        reputation.adjustReputationScore(
            msg.sender,
            IReputation.ReasonType.BR_CREATE_COLLATERAL
        );
    }

    /**
    * @dev cancel collateral function and return back collateral
    * @param  _collateralId is id of collateral
    */
    function withdrawCollateral(uint256 _collateralId) external whenNotPaused {
        Collateral storage collateral = collaterals[_collateralId];
        require(collateral.owner == msg.sender, '0'); //owner
        require(collateral.status == CollateralStatus.OPEN, '1'); //col

        PawnLib.safeTransfer(
            collateral.collateralAddress,
            address(this),
            collateral.owner,
            collateral.amount
        );

        // Remove relation of collateral and offers
        CollateralOfferList storage collateralOfferList = collateralOffersMapping[_collateralId];
        if (collateralOfferList.isInit == true) {
            for (uint256 i = 0; i < collateralOfferList.offerIdList.length; i++) {
                uint256 offerId = collateralOfferList.offerIdList[i];
                Offer storage offer = collateralOfferList.offerMapping[offerId];
                emit CancelOfferEvent(
                    offerId,
                    _collateralId,
                    offer.owner
                );
            }
            delete collateralOffersMapping[_collateralId];
        }

        delete collaterals[_collateralId];
        emit WithdrawCollateralEvent(_collateralId, msg.sender);

        // Adjust reputation score
        reputation.adjustReputationScore(
            msg.sender,
            IReputation.ReasonType.BR_CANCEL_COLLATERAL
        );
    }

    /** ==================== Offer functions ==================== */

    /**
    * @dev create Collateral function, collateral will be stored in this contract
    * @param _collateralId is id of collateral
    * @param _repaymentAsset is address of repayment token
    * @param _duration is duration of this offer
    * @param _loanDurationType is type for calculating loan duration
    * @param _repaymentCycleType is type for calculating repayment cycle
    * @param _liquidityThreshold is ratio of assets to be liquidated
    */
    function createOffer(
        uint256 _collateralId,
        address _repaymentAsset,
        uint256 _loanAmount,
        uint256 _duration,
        uint256 _interest,
        uint8 _loanDurationType,
        uint8 _repaymentCycleType,
        uint256 _liquidityThreshold
    )
        external 
        whenNotPaused 
        returns (uint256 _idx)
    {
        Collateral storage collateral = collaterals[_collateralId];
        require(collateral.status == CollateralStatus.OPEN, '0'); // col
        // validate not allow for collateral owner to create offer
        require(collateral.owner != msg.sender, '1'); // owner
        // Validate ower already approve for this contract to withdraw
        require(IERC20Upgradeable(collateral.loanAsset).allowance(msg.sender, address(this)) >= _loanAmount, '2'); // not-apr

        // Get offers of collateral
        CollateralOfferList storage collateralOfferList = collateralOffersMapping[_collateralId];
        if (!collateralOfferList.isInit) {
            collateralOfferList.isInit = true;
        }
        // Create offer id       
        _idx = numberOffers;

        // Create offer data
        Offer storage _offer = collateralOfferList.offerMapping[_idx];

        _offer.create(
            _repaymentAsset,
            _loanAmount,
            _duration,
            _interest,
            _loanDurationType,
            _repaymentCycleType,
            _liquidityThreshold
        );

        collateralOfferList.offerIdList.push(_idx);

        ++numberOffers;

        emit CreateOfferEvent(_idx, _collateralId, _offer);
        
        // Adjust reputation score
        reputation.adjustReputationScore(
            msg.sender,
            IReputation.ReasonType.LD_CREATE_OFFER
        );
    }

    /**
    * @dev cancel offer function, used for cancel offer
    * @param  _offerId is id of offer
    * @param _collateralId is id of collateral associated with offer
    */
    function cancelOffer(uint256 _offerId, uint256 _collateralId)
        external
        whenContractNotPaused
    {
        CollateralOfferList
            storage collateralOfferList = collateralOffersMapping[
                _collateralId
            ];
        require(collateralOfferList.isInit == true, "0"); // col
        // Lấy thông tin collateral
        Collateral storage collateral = collaterals[_collateralId];
        Offer storage offer = collateralOfferList.offerMapping[_offerId];

        // offer.cancel(_offerId, collateral, collateralOfferList);

        // delete collateralOfferList.offerIdList[
        //     collateralOfferList.offerIdList.length - 1
        // ];
        // kiểm tra người gọi hàm -> rẽ nhánh event
        // neu nguoi goi la owner cua collateral  => reject offer.

        if (msg.sender == collateral.owner) {
            offer.cancel(_offerId, collateral.owner, collateralOfferList);
            
            delete collateralOfferList.offerIdList[
                collateralOfferList.offerIdList.length - 1
            ];
            emit CancelOfferEvent(_offerId, _collateralId, offer.owner);
        }

        // neu nguoi goi la owner cua offer thi canel offer
        if (msg.sender == offer.owner) {
            offer.cancel(_offerId, address(0), collateralOfferList);
            
            delete collateralOfferList.offerIdList[
                collateralOfferList.offerIdList.length - 1
            ];
            emit CancelOfferEvent(_offerId, _collateralId, msg.sender);

            // Adjust reputation score
            reputation.adjustReputationScore(
                msg.sender,
                IReputation.ReasonType.LD_CANCEL_OFFER
            );
        }
    }
}