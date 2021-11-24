// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;
import "./PawnNFTLib.sol";
import "../../base/BaseInterface.sol";

interface IPawnNFT {
    function createContract(
        ContractRawData_NFT memory _contractData,
        uint256 _UID
    ) external returns (uint256 _idx);
}
