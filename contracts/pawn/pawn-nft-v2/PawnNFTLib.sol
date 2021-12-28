// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import "../nft_evaluation/interface/IDFY_Hard_Evaluation.sol";
import "../pawn-base/IPawnNFTBase.sol";
import "../../libs/CommonLib.sol";

library PawnNFTLib {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    function safeTranferNFTToken(
        address _nftToken,
        address _from,
        address _to,
        uint256 _id,
        uint256 _amount,
        CollectionStandard collectionStandard
    ) internal {
        // check address token
        require(
            _nftToken != address(0),
            "Address token must be different address(0)."
        );

        // check address from
        require(
            _from != address(0),
            "Address from must be different address(0)."
        );

        // check address from
        require(_to != address(0), "Address to must be different address(0).");

        if (collectionStandard == CollectionStandard.ERC721) {
            // Check balance of from,
            require(
                IERC721Upgradeable(_nftToken).balanceOf(_from) >= _amount,
                "Your balance not enough."
            );

            // Transfer token
            IERC721Upgradeable(_nftToken).safeTransferFrom(_from, _to, _id, "");
        } else {
            // Check balance of from,
            require(
                IERC1155Upgradeable(_nftToken).balanceOf(_from, _id) >= _amount,
                "Your balance not enough."
            );

            // Transfer token
            IERC1155Upgradeable(_nftToken).safeTransferFrom(
                _from,
                _to,
                _id,
                _amount,
                ""
            );
        }
    }

    /**
     * @dev Calculate the duration of the contract
     * @param  durationType is loan duration type of contract (WEEK/MONTH)
     * @param  duration is duration of contract
     */
    function calculateContractDuration(
        IEnums.LoanDurationType durationType,
        uint256 duration
    ) internal pure returns (uint256 inSeconds) {
        if (durationType == IEnums.LoanDurationType.WEEK) {
            // inSeconds = 7 * 24 * 3600 * duration;
            inSeconds = 600 * duration; //test
        } else {
            // inSeconds = 30 * 24 * 3600 * duration;
            inSeconds = 900 * duration; // test
        }
    }

    function isPrepaidChargeRequired(
        IEnums.LoanDurationType durationType,
        uint256 startDate,
        uint256 endDate
    ) internal pure returns (bool) {
        uint256 week = 600;
        uint256 month = 900;

        if (durationType == IEnums.LoanDurationType.WEEK) {
            // if loan contract only lasts one week
            if ((endDate - startDate) <= week) {
                return false;
            } else {
                return true;
            }
        } else {
            // if loan contract only lasts one month
            if ((endDate - startDate) <= month) {
                return false;
            } else {
                return true;
            }
        }
    }

    function calculatedueDateTimestampInterest(
        IEnums.LoanDurationType durationType
    ) internal pure returns (uint256 duedateTimestampInterest) {
        if (durationType == IEnums.LoanDurationType.WEEK) {
            duedateTimestampInterest = 180;
        } else {
            duedateTimestampInterest = 300;
        }
    }

    function calculatedueDateTimestampPenalty(
        IEnums.LoanDurationType durationType
    ) internal pure returns (uint256 duedateTimestampInterest) {
        if (durationType == IEnums.LoanDurationType.WEEK) {
            duedateTimestampInterest = 600 - 180;
        } else {
            duedateTimestampInterest = 900 - 300;
        }
    }
}

library CollateralLib_NFT {
    function create(
        IPawnNFTBase.NFTCollateral storage self,
        address _nftContract,
        uint256 _nftTokenId,
        uint256 _expectedlLoanAmount,
        address _loanAsset,
        uint256 _nftTokenQuantity,
        uint256 _expectedDurationQty,
        IEnums.LoanDurationType _durationType
    ) internal {
        self.owner = msg.sender;
        self.nftContract = _nftContract;
        self.nftTokenId = _nftTokenId;
        self.expectedlLoanAmount = _expectedlLoanAmount;
        self.loanAsset = _loanAsset;
        self.nftTokenQuantity = _nftTokenQuantity;
        self.expectedDurationQty = _expectedDurationQty;
        self.durationType = _durationType;
        self.status = IEnums.CollateralStatus.OPEN;
    }
}

library OfferLib_NFT {
    function create(
        IPawnNFTBase.NFTOffer storage self,
        address repaymentAsset,
        uint256 loanToValue,
        uint256 loanAmount,
        uint256 interest,
        uint256 duration,
        uint256 liquidityThreshold,
        IEnums.LoanDurationType _loanDurationType,
        IEnums.LoanDurationType _repaymentCycleType
    ) internal {
        self.owner = msg.sender;
        self.repaymentAsset = repaymentAsset;
        self.loanToValue = loanToValue;
        self.loanAmount = loanAmount;
        self.interest = interest;
        self.duration = duration;
        self.status = IEnums.OfferStatus.PENDING;
        self.loanDurationType = IEnums.LoanDurationType(_loanDurationType);
        self.repaymentCycleType = IEnums.LoanDurationType(_repaymentCycleType);
        self.liquidityThreshold = liquidityThreshold;
    }

    function cancel(
        IPawnNFTBase.NFTOffer storage self,
        uint256 _id,
        address _collateralOwner,
        IPawnNFTBase.NFTCollateralOfferList storage _collateralOfferList
    ) internal {
        require(_collateralOfferList.isInit == true, "1"); // offer-col
        require(
            self.owner == msg.sender || _collateralOwner == msg.sender,
            "2"
        ); // owner
        require(self.status == IEnums.OfferStatus.PENDING, "3"); // offer

        delete _collateralOfferList.offerMapping[_id];
        for (uint256 i = 0; i < _collateralOfferList.offerIdList.length; i++) {
            if (_collateralOfferList.offerIdList[i] == _id) {
                _collateralOfferList.offerIdList[i] = _collateralOfferList
                    .offerIdList[_collateralOfferList.offerIdList.length - 1];
                break;
            }
        }
        delete _collateralOfferList.offerIdList[
            _collateralOfferList.offerIdList.length - 1
        ];
    }
}
