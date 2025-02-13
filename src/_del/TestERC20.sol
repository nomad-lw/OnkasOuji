// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract TestERC20 is ERC20, Ownable {
    constructor() ERC20("Test GOLD", "tGOLD") Ownable(msg.sender) {
        _mint(msg.sender, 90_000_000_000 * 10 ** decimals());
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}
