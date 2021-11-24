// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

interface HubInterface {
    struct SystemConfig {
        address systemFeeWallet;
        address systemFeeToken;
        address Admin;
        address Operator;
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

    function getContractAddress(string memory _nameContract)
        external
        view
        returns (address _contractAddres);

    function getSystemConfig()
        external
        view
        returns (
            address _FeeWallet,
            address _FeeToken,
            address _admin,
            address _operator
        );
}
