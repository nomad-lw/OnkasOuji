// test/MyContract.t.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/AnNFT.sol";

contract AnNFT is Test {
    AnNFToken public nft_contract;

    function setUp() public {
        nft_contract = new AnNFToken(true); // Provide the boolean parameter
    }

    // function testTotalSupply() public {
    //     assertEq(nft_contract.totalSupply(), 100);
    // }

    // Additional test cases you might want to add
    function testOwnership() public view {
        assertEq(nft_contract.ownerOf(0), address(this));
        assertEq(nft_contract.ownerOf(99), address(this));
    }

    function testBalanceOf() public view {
        assertEq(nft_contract.balanceOf(address(this)), 100);
    }

    // // Test that minting fails after construction
    // function testFailMintAfterConstruction() public {
    //     // This should fail as ERC721Consecutive only allows batch minting during construction
    //     nft_contract._mintConsecutive(address(this), 1);
    // }
    //
    function testFailTokenOutOfBounds() public view {
        nft_contract.ownerOf(100); // Should fail since token ID 100 doesn't exist
    }
}
