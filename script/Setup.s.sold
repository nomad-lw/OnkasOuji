// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.26;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Script} from "forge-std/Script.sol";
import {OnkasOujiGame} from "../src/OnkasOujiGame.sol";
import {TestERC20} from "../src/TestERC20.sol";
import {TestNFT} from "../src/TestERC721.sol";

import {console} from "forge-std/console.sol";

contract SetupScript is Script {
    OnkasOujiGame public mainContract;
    TestERC20 public testToken;
    TestNFT public testNFT;
    uint256 deployer;
    uint256 entropyProvider;
    uint256[4] test_wallets;

    function setUp() public {
        // Load deployed addresses from deployments.json
        try vm.readFile("./out/deployments.json") returns (string memory json) {
            bytes memory mainContractBytes = vm.parseJson(json, "$.mainContract");
            bytes memory testTokenBytes = vm.parseJson(json, "$.testToken");
            bytes memory testNFTBytes = vm.parseJson(json, "$.testNFT");

            address mainContractAddress = abi.decode(mainContractBytes, (address));
            address testTokenAddress = abi.decode(testTokenBytes, (address));
            address testNFTAddress = abi.decode(testNFTBytes, (address));

            deployer = vm.envUint("PRIVATE_KEY");
            entropyProvider = deployer;
            // uint256[4] memory test_wallets;
            for (uint8 i = 0; i < 4; i++) {
                test_wallets[i] = vm.envUint(string.concat("TEST_PK", vm.toString(i + 1)));
            }

            mainContract = OnkasOujiGame(mainContractAddress);
            testToken = TestERC20(testTokenAddress);
            testNFT = TestNFT(testNFTAddress);
        } catch {
            revert("Failed to load deployment addresses");
        }
    }

    function run() public virtual {
        // uint256 deployer = vm.envUint("PRIVATE_KEY");
        address payable deployer_addr = payable(vm.addr(deployer));
        vm.startBroadcast(deployer);

        // Mint some tokens to the deployer
        if (testToken.totalSupply() != 100_000_000_000) testToken.mint(deployer_addr, 10_000_000_000 * 10 ** 18);
        for (uint8 i = 0; i < 4; i++) {
            address payable twallet = payable(vm.addr(test_wallets[i]));
            if (twallet.balance < 5 gwei * 10 ** 8) twallet.transfer(5 gwei * 10 ** 8);
            if (testToken.balanceOf(vm.addr(test_wallets[i])) < 5_000 * 10 ** 18) testToken.transfer(vm.addr(test_wallets[i]), 5_000 * 10 ** 18);
        }

        // return;
        // Mint some NFTs
        while (testNFT.balanceOf(deployer_addr) < 2) testNFT.mint(deployer_addr);
        for (uint8 i = 0; i < 4; i++) {
            if (testNFT.balanceOf(vm.addr(test_wallets[i])) != 1) testNFT.mint(vm.addr(test_wallets[i]));
        }

        // Approve main contract to spend tokens
        testToken.approve(address(mainContract), type(uint256).max);
        mainContract.register(bytes32(abi.encodePacked("deployer")));
        vm.stopBroadcast();
        for (uint8 i = 0; i < 4; i++) {
            vm.startBroadcast(test_wallets[i]);
            testToken.approve(address(mainContract), type(uint256).max);
            mainContract.register(bytes32(abi.encodePacked(string.concat("test_wallet_", vm.toString(i + 1)))));
            vm.stopBroadcast();
        }

        // Approve main contract for NFTs
        // testNFT.setApprovalForAll(address(mainContract), true);

        state_snapshot();
    }

    function state_snapshot() public view {
        // uint256 deployer = vm.envUint("PRIVATE_KEY");
        console.log("--- Wallets ---");
        address deployer_addr = vm.addr(deployer);
        console.log("Deployer: %s; tDMT: %s gwei", deployer_addr, deployer_addr.balance / 1 gwei);
        for (uint8 i = 0; i < 4; i++) {
            address twallet = vm.addr(test_wallets[i]);
            console.log("Test Wallet %s: %s; tDMT: %s gwei", i + 1, twallet, twallet.balance / 1 gwei);
        }

        console.log("\n--- Contracts ---");
        console.log("Main Contract:", address(mainContract));
        console.log("Test Token:", address(testToken));
        console.log("Test NFT: ", address(testNFT));

        console.log("\n--- Token ---");
        console.log("Name:", testToken.name());
        console.log("Symbol:", testToken.symbol());
        console.log("Decimals:", testToken.decimals());
        console.log("Total Supply:", testToken.totalSupply() / 10 ** testToken.decimals());
        console.log("Balance of deployer:", _getFormattedBalance(deployer_addr, false));
        console.log("Balance of main contract:", _getFormattedBalance(address(mainContract), false));
        for (uint8 i = 0; i < 4; i++) {
            console.log("Balance of test wallet %s:", i + 1, _getFormattedBalance(vm.addr(test_wallets[i]), false));
        }

        console.log("\n--- NFT ---");
        console.log("Name:", testNFT.name());
        console.log("Symbol:", testNFT.symbol());
        console.log("Total Supply:", testNFT.totalSupply());
        console.log("Balance of deployer:", _getFormattedBalance(deployer_addr, true));
        console.log("Balance of main contract:", _getFormattedBalance(address(mainContract), true));
        for (uint8 i = 0; i < 4; i++) {
            console.log("Balance of test wallet %s:", i + 1, _getFormattedBalance(vm.addr(test_wallets[i]), true));
        }

        console.log("\n--- Game ---");
    }

    function _getFormattedBalance(address account, bool nft) internal view returns (string memory) {
        uint256 balance = nft ? testNFT.balanceOf(account) : testToken.balanceOf(account);
        uint8 decimals = nft ? 0 : testToken.decimals();
        if (decimals == 0 || balance == 0) return Strings.toString(balance);

        uint256 pre = balance / (10 ** decimals);
        uint256 post = balance % (10 ** decimals);

        string memory preStr = Strings.toString(pre);
        string memory postStr = Strings.toString(post);

        // Pad post-decimal portion with leading zeros
        uint8 padding = decimals - uint8(bytes(postStr).length);
        for (uint8 i = 0; i < padding; i++) {
            postStr = string.concat("0", postStr);
        }

        return string.concat(preStr, ".", postStr);
    }
}
