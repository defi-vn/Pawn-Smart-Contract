// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "../../hub/Hub.sol";
import "../../hub/HubLib.sol";
import "../../hub/HubInterface.sol";
import "../reputation/IReputation.sol";
import "../exchange/IExchange.sol";
import "../nft_evaluation/interface/IDFY_Hard_Evaluation.sol";
import "../../base/BaseContract.sol";

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
        // admin = address(msg.sender);
        // ZOOM = _zoom;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC165Upgradeable, ERC1155ReceiverUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function emergencyWithdraw(address _token) external whenPaused onlyAdmin {
        CommonLib.safeTransfer(
            _token,
            address(this),
            msg.sender,
            CommonLib.calculateAmount(_token, address(this))
        );
    }

    // /** ===================================== REPUTATION FUNCTIONS & STATES ===================================== */

    // IReputation public reputation;

    // function setReputationContract(address _reputationAddress)
    //     external
    //     onlyRole(DEFAULT_ADMIN_ROLE)
    // {
    //     reputation = IReputation(_reputationAddress);
    // }

    // /**==========================   ExchangeRate   ========================= */
    // Exchange public exchange;

    // function setExchangeRate(address _exchange)
    //     external
    //     onlyRole(DEFAULT_ADMIN_ROLE)
    // {
    //     exchange = Exchange(_exchange);
    // }

    function getEvaluation() internal view returns (address) {
        return
            HubInterface(hubContract).getContractAddress(
                (type(IDFY_Hard_Evaluation).interfaceId)
            );
    }

    function getReputation()
        internal
        view
        returns (address _ReputationAddress)
    {
        (_ReputationAddress, ) = HubInterface(hubContract).getContractAddress(
            (type(IDFY_Hard_Evaluation).interfaceId)
        );
    }

    /**================== Exchange======= */
    function getExchange() internal view returns (address _exchangeAddress) {
        (_exchangeAddress, ) = HubInterface(hubContract).getContractAddress(
            type(IExchange).interfaceId
        );
    }
}
