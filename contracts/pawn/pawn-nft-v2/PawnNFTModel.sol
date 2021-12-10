// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/IAccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "../../base/BaseContract.sol";
import "../../hub/HubLib.sol";
import "../../hub/HubInterface.sol";
import "../reputation/IReputation.sol";
import "../exchange/IExchange.sol";
import "../nft_evaluation/interface/IDFY_Hard_Evaluation.sol";

abstract contract PawnNFTModel is
    ERC1155HolderUpgradeable,
    ERC721HolderUpgradeable,
    BaseContract
{
    // AssetEvaluation assetEvaluation;

    // mapping(address => uint256) public whitelistCollateral;
    // address public feeWallet;
    // uint256 public penaltyRate;
    // uint256 public systemFeeRate;
    // uint256 public lateThreshold;
    // uint256 public prepaidFeeRate;

    // uint256 public ZOOM;

    // address public admin;
    // address public operator;

    // DFY_Physical_NFTs dfy_physical_nfts;
    // AssetEvaluation assetEvaluation;

    function initialize(address _hub) public initializer {
        __BaseContract_init(_hub);
    }

    /** ==================== Standard interface function implementations ==================== */
    function supportsInterface(bytes4 interfaceId)
        public
        virtual
        view
        override(ERC165Upgradeable, ERC1155ReceiverUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev Emergency widthdraw
     */
    function emergencyWithdraw(address _token) external whenPaused onlyAdmin {
        CommonLib.safeTransfer(
            _token,
            address(this),
            msg.sender,
            CommonLib.calculateAmount(_token, address(this))
        );
    }

    /** ===================================== Evaluation, Reputation, Exchange ===================================== */

    function getEvaluation() internal view returns (address _Evaluation) {
        (_Evaluation, ) = HubInterface(contractHub).getContractAddress(
            (type(IDFYHardEvaluation).interfaceId)
        );
    }

    function getReputation()
        internal
        view
        returns (address _ReputationAddress)
    {
        (_ReputationAddress, ) = HubInterface(contractHub).getContractAddress(
            (type(IDFYHardEvaluation).interfaceId)
        );
    }

    function getExchange() internal view returns (address _exchangeAddress) {
        (_exchangeAddress, ) = HubInterface(contractHub).getContractAddress(
            type(IExchange).interfaceId
        );
    }
}
