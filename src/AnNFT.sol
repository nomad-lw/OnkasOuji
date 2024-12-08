pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Consecutive.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract AnNFToken is ERC721Consecutive, Ownable {
    uint256 private _totalSupply;

    constructor(bool _init) ERC721("MyToken", "MTK") Ownable(msg.sender) {
        _mintConsecutive(msg.sender, 100); // Mints tokens 0-99
        _totalSupply = 100;
    }
}
