// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/IAccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import "../pawn/libs/CommonLib.sol";
import "../pawn/hub/HubLib.sol";
import "../pawn/hub/HubInterface.sol";
import "./BaseInterface.sol";

abstract contract BaseContract is
    Initializable,
    UUPSUpgradeable,
    PausableUpgradeable,
    ERC165Upgradeable,
    BaseInterface
{
    address public contractHub;

    function __BaseContract_init(address _hub) internal initializer {
        __BaseContract_init_unchained();

        contractHub = _hub;
    }

    function __BaseContract_init_unchained() internal initializer {
        __UUPSUpgradeable_init();
        __Pausable_init();
    }

    modifier onlyRoleAdmin() {
        _onlyRole(HubRoles.DEFAULT_ADMIN_ROLE);
        _;
    }

    function _onlyRole(bytes32 role) private view {
        require(
            IAccessControlUpgradeable(contractHub).hasRole(role, msg.sender)
        );
    }

    modifier whenContractNotPaused() {
        _whenNotPaused();
        _;
    }

    function _whenNotPaused() private view {
        require(!paused(), "Pausable: paused");
    }

    function pause() external onlyRoleAdmin {
        _pause();
    }

    function unPause() external onlyRoleAdmin {
        _unpause();
    }

    function setContractHub(address _hub) external onlyRoleAdmin {
        contractHub = _hub;
    }

    // function _registerToHub() private {
    //     HubInterface(contractHub).registerContract(this.signature(), address(this));
    //     IAccessControlUpgradeable(contractHub).renounceRole(HubRoleLib.REGISTRANT, address(this));
    // }

    function _authorizeUpgrade(address) internal override onlyRoleAdmin {}
}
