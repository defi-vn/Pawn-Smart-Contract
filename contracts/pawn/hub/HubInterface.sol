// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

interface HubInterface {
    struct SystemConfig {
        address systemFeeWallet;
        address systemFeeToken;
        // address Admin;
        // address Operator;
    }

    struct PawnConfig {
        uint256 ZOOM;
        uint256 systemFeeRate;
        uint256 penaltyRate;
        uint256 prepaidFeeRate;
        uint256 lateThreshold;
        mapping(address => uint256) whitelistedCollateral;
    }

    struct PawnNFTConfig {
        uint256 ZOOM;
        uint256 systemFeeRate;
        uint256 penaltyRate;
        uint256 prepaidFeeRate;
        uint256 lateThreshold;
        mapping(address => uint256) whitelistedEvaluationContract;
        mapping(address => uint256) whitelistedCollateral;
    }

    struct NFTCollectionConfig {
        uint256 collectionCreatingFee;
        uint256 mintingFee;
    }

    struct NFTMarketConfig {
        uint256 ZOOM;
        uint256 marketFeeRate;
        address marketFeeWallet;
    }

    /** Functions */
    /** ROLES */
    function AdminRole() external pure returns (bytes32);
    function OperatorRole() external pure returns (bytes32);
    function PauserRole() external pure returns (bytes32);
    function EvaluatorRole() external pure returns (bytes32);

    function registerContract(bytes4 nameContract, address contractAddress)
        external;

    function getContractAddress(bytes4 signature)
        external
        view
        returns (address contractAddres);

    function getSystemConfig()
        external
        view
        returns (address feeWallet, address feeToken);

    function getEvaluationContract(address _evaluationContractAddress)
        external
        view
        returns (uint256 _status);

    function getWhitelistCollateral_NFT(address _token)
        external
        view
        returns (uint256 _status);

    function getPawnNFTConfig()
        external
        view
        returns (
            uint256 _zoom,
            uint256 _FeeRate,
            uint256 _penaltyRate,
            uint256 _prepaidFeedRate,
            uint256 _lateThreshold
        );

    function getWhitelistCollateral(address _token)
        external
        view
        returns (uint256 _status);

    function getPawnConfig()
        external
        view
        returns (
            uint256 _zoom,
            uint256 _FeeRate,
            uint256 _penaltyRate,
            uint256 _prepaidFeeRate,
            uint256 _lateThreshold
        );

    function getNFTCollectionConfig()
        external
        view
        returns (uint256 collectionCreatingFee, uint256 mintingFee);

    function getNFTMarketConfig()
        external
        view
        returns (
            uint256 zoom,
            uint256 marketFeeRate,
            address marketFeeWallet
        );
}
