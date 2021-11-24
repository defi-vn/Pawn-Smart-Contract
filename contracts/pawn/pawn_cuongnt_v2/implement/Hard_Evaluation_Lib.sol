// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

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


}