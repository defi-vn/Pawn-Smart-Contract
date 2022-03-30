/* SPDX-License-Identifier: UNLICENSED */
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract LoanToken is ERC20, ERC20Burnable, Ownable {
    mapping(address => bool) private _operators;
    event SetOperator(address operator, bool isOperator);
    event MintTIA(address received, uint256 amount);
    event BurnTia(address account, uint256 amount);

    constructor() ERC20("LoanToken", "LT") {
        _mint(msg.sender, 1000000 * 10**decimals());
    }

    modifier onlyOperator() {
        require(_operators[_msgSender()]);
        _;
    }

    function setOperator(address operator, bool isOperator) external onlyOwner {
        _operators[operator] = isOperator;
        emit SetOperator(operator, true);
    }

    function mint(address received, uint256 amount) external onlyOperator {
        ERC20._mint(received, amount);
        emit MintTIA(received, amount);
    }

    function burnFrom(address account, uint256 amount)
        public
        override
        onlyOperator
    {
        _burn(account, amount);
        emit BurnTia(account, amount);
    }
}
