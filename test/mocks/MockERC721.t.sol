// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.26;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract TestNFT is ERC721, Ownable {
    uint256 private _nextTokenId;

    constructor() ERC721("Test NFT", "TNFT") Ownable(msg.sender) {}

    function totalSupply() external view returns (uint256) {
        return _nextTokenId;
    }

    function mint(address to) external returns (uint256) {
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        return tokenId;
    }
}
