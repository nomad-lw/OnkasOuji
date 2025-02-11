// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "forge-std/console.sol";

contract GasTest is Test {
    function testGas() public {
        uint256 startGas = gasleft();

        // Your code here
        // For example:
        uint a = 1;
        uint b = 2;
        uint c = a + b;

        uint256 gasUsed = startGas - gasleft();
        console.log("Gas used:", gasUsed);
    }
}
