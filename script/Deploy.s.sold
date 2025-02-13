// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {OnkasOujiGame} from "../src/OnkasOujiGame.sol";
import {TestERC20} from "../src/TestERC20.sol";
import {TestNFT} from "../src/TestERC721.sol";

address constant ENTROPY = 0x5744Cbf430D99456a0A8771208b674F27f8EF0Fb;
address constant PROVIDER = 0x6CC14824Ea2918f5De5C2f75A9Da968ad4BD6344;
address constant TOKEN = 0x9Ff1df75E883Feda565359545F63095fb710d47f;
address constant NFT = 0x1cbF8779107A7a2f54019A9230D73CAAB1A38C19;

contract DeployScript is Script {
    function run() external returns (OnkasOujiGame, TestERC20, TestNFT) {
        uint256 deployer = vm.envUint("PRIVATE_KEY");
        uint256 marketing = vm.envUint("MARKETING_PK");
        vm.startBroadcast(deployer);

        // Deploy contracts
        TestERC20 testToken = new TestERC20();
        TestNFT testNFT = new TestNFT();
        OnkasOujiGame game = new OnkasOujiGame(address(NFT), address(TOKEN), address(ENTROPY), address(PROVIDER), address(vm.addr(marketing)));

        vm.stopBroadcast();

        save_deployment("mainContract", address(game), "testToken", address(testToken), "testNFT", address(testNFT));
        return (game, testToken, testNFT);
    }

    function save_deployment(string memory mainLabel, address main, string memory tokenLabel, address token, string memory nftLabel, address nft)
        internal
    {
        // string memory deployment = vm.toString(
        //     abi.encodePacked(
        //         '{"', mainLabel, '":"',vm.toString(main),'",',
        //         '"',tokenLabel,'":"',vm.toString(token),'",',
        //         '"',nftLabel,'":"',vm.toString(nft),'"}'
        //     )
        // );

        string memory deployment = string.concat(
            "{",
            '"network": "',
            vm.toString(block.chainid),
            '",',
            '"mainContract": "',
            vm.toString(address(main)),
            '",',
            '"testToken": "',
            vm.toString(address(token)),
            '",',
            '"testNFT": "',
            vm.toString(address(nft)),
            '"',
            "}"
        );

        vm.writeFile("./out/deployments.json", deployment);
    }
}
