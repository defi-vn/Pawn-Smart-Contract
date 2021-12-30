// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../../../dfy-nft/DFY721Base.sol";
import "../interface/IDFYHard721.sol";

contract DFYHard721 is DFY721Base, IDFYHard721 {
    using Counters for Counters.Counter;
    using Address for address;

    // Minter role
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    // Contract call create collection
    address public factory;

    Counters.Counter private _tokenIdCounter;

    constructor(
        string memory _name,
        string memory _symbol,
        address payable _owner,
        string memory _collectionCID,
        address _hub,
        address _evaluationAddress
    ) DFY721Base(_name, _symbol, _owner, 0, _collectionCID, _hub) {
        _setupRole(MINTER_ROLE, _owner);

        if (msg.sender.isContract()) {
            factory = msg.sender;
        }

        if (
            _evaluationAddress.isContract() && _evaluationAddress != address(0)
        ) {
            _setupRole(MINTER_ROLE, _evaluationAddress);
        }
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(IERC165, DFY721Base)
        returns (bool)
    {
        return
            interfaceId == type(IDFYHard721).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function safeMint(address owner, string memory tokenCID)
        public
        virtual
        override
        onlyRole(MINTER_ROLE)
        returns (uint256)
    {
        uint256 tokenId = _tokenIdCounter.current();
        // Mint token
        _safeMint(owner, tokenId);

        _setTokenURI(tokenId, tokenCID);

        _tokenIdCounter.increment();

        return tokenId;
    }
}
