// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

interface IEIP2612 {
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;

    function nonces(address owner) external view returns (uint256);
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

contract TokenMetaTxCheckerTest is Test {
    function setUp() public {
        // Optional: Setup fork
        // vm.createSelectFork(vm.envString("RPC_URL"));
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"));
    }

    function testPermitSupport(address tokenAddress, string memory token_label) public view {
        if (tokenAddress == address(0)) {
            tokenAddress = vm.envAddress("TOKEN_ADDRESS");
        }

        console.log("\nChecking EIP-2612 permit support for: %s (%s)", tokenAddress, token_label);

        try IEIP2612(tokenAddress).DOMAIN_SEPARATOR() returns (bytes32 domainSeparator) {
            console.log("SUCCESS Token supports EIP-2612 permit");
            console.log("Domain Separator:", vm.toString(domainSeparator));
        } catch {
            console.log("FAILURE Token does not support EIP-2612 permit");
        }
    }

    function testKnownTokens() public view {
        address[] memory tokens = new address[](3);
        // tokens[0] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC
        // tokens[1] = 0x6B175474E89094C44Da98b954EedeAC495271d0F; // DAI
        // tokens[2] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH
        tokens[0] = 0x6F5e2d3b8c5C5c5F9bcB4adCF40b13308e688D4D; // GOLD
        tokens[1] = 0x754cDAd6f5821077d6915004Be2cE05f93d176f8; // DMT
        tokens[2] = 0xE01e3b20C5819cf919F7f1a2b4C18bBfd222F376; // WETH

        string[] memory token_labels = new string[](3);
        // token_labels[0] = "USDC";
        // token_labels[1] = "DAI";
        // token_labels[2] = "WETH";
        token_labels[0] = "GOLD";
        token_labels[1] = "WDMT";
        token_labels[2] = "WETH";

        console.log("\nKnown Token on ChainID: 1996");

        for (uint256 i = 0; i < tokens.length; i++) {
            testPermitSupport(tokens[i], token_labels[i]);
        }
    }
}
