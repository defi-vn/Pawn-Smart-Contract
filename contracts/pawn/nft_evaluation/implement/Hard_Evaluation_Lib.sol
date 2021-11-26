// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";

enum CollectionStandard{
    Collection_721,
    Collection_1155
}

library Hard_Evaluation_Lib {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    function safeTransfer(
        address currency,
        address from,
        address to,
        uint256 amount
    ) internal {
        if (currency == address(0)) {
            require(from.balance >= amount, "not-enough-balance");
            // Handle BNB
            if (to == address(this)) {
                // Send to this contract
            } else if (from == address(this)) {
                // Send from this contract
                (bool success, ) = to.call{value: amount}("");
                require(success, "fail-transfer-bnb");
            } else {
                // Send from other address to another address
                revert("not-allow-transfer");
            }

        } else {
            // Handle ERC20
            uint256 prebalance = IERC20Upgradeable(currency).balanceOf(to);
            require(
                IERC20Upgradeable(currency).balanceOf(from) >= amount,
                "not-enough-balance"
            );
            if (from == address(this)) {
                // transfer direct to to
                IERC20Upgradeable(currency).safeTransfer(to, amount);
            } else {
                require(
                    IERC20Upgradeable(currency).allowance(from, address(this)) >=
                        amount,
                    "not-enough-allowance"
                );
                IERC20Upgradeable(currency).safeTransferFrom(from, to, amount);
            }
            require(
                IERC20Upgradeable(currency).balanceOf(to) - amount == prebalance,
                "not-transfer-enough"
            );
        }
    }

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

        if(collectionStandard == CollectionStandard.Collection_721){
             // Check balance of from,
            require(
                IERC721Upgradeable(_nftToken).balanceOf(_from) >= _amount,
                "Your balance not enough."
            );

            // Transfer token
            IERC721Upgradeable(_nftToken).safeTransferFrom(_from, _to, _id, "");
        }else{
             // Check balance of from,
            require(
                IERC1155Upgradeable(_nftToken).balanceOf(_from, _id) >= _amount,
                "Your balance not enough."
            );

            // Transfer token
            IERC1155Upgradeable(_nftToken).safeTransferFrom(_from, _to, _id, _amount,"");
        }
       
    }


}