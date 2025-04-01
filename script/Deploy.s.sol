// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {OnkasOujiGame} from "../src/OnkasOujiGame.sol";
// import {TestERC20} from "../src/TestERC20.sol";
// import {TestNFT} from "../src/TestERC721.sol";

// Legend: TN: Testnet; MN: Mainnet
address constant TN_TOKEN = 0x9Ff1df75E883Feda565359545F63095fb710d47f;
address constant TN_NFT = 0x1cbF8779107A7a2f54019A9230D73CAAB1A38C19;
address constant MN_TOKEN = 0x0000000000000000000000000000000000000000;
address constant MN_NFT = 0x0000000000000000000000000000000000000000;

address constant TN_PYTH_ENTROPY = 0x5744Cbf430D99456a0A8771208b674F27f8EF0Fb;
address constant TN_PYTH_PROVIDER = 0x6CC14824Ea2918f5De5C2f75A9Da968ad4BD6344;
address constant MN_PYTH_ENTROPY = 0x5744Cbf430D99456a0A8771208b674F27f8EF0Fb;
address constant MN_PYTH_PROVIDER = 0x52DeaA1c84233F7bb8C8A45baeDE41091c616506;
address constant TN_RANDOMIZER = 0xe360c1285E2ECB36C16faFa62e86B30AB5fb7dB3;
address constant MN_RANDOMIZER = 0xf43CC283CB83a919BFA9226D0BC49Eefcc4325Db;

// privileged roles
uint constant ROLE_OPERATOR = 1 <<0;
uint constant ROLE_SAV_PROVER = 1 <<1;

contract DeployScript is Script {
    function run() external returns (OnkasOujiGame) {
        uint256 deployer = vm.envUint("PRIVATE_KEY");
        uint256 marketing = vm.envUint("MARKETING_PK");
        address operator = vm.envAddress("ADDR_OPERATOR");
        address sav_prover = vm.envAddress("ADDR_SAV_PROVER");
        uint SAV_PK_X = vm.envUint("VRF_PUBLIC_KEY_X");
        uint SAV_PK_Y = vm.envUint("VRF_PUBLIC_KEY_Y");
        bool prod = vm.envBool("DEPLOY_MAINNET");

        address token_gold = prod ? MN_TOKEN : TN_TOKEN;
        address nft_onkas = prod ? MN_NFT : TN_NFT;
        address pyth_entropy = prod ? MN_PYTH_ENTROPY : TN_PYTH_ENTROPY;
        address pyth_provider = prod ? MN_PYTH_PROVIDER : TN_PYTH_PROVIDER;
        address randomizer = prod ? MN_RANDOMIZER : TN_RANDOMIZER;

        vm.startBroadcast(deployer);

        // Deploy contract
        OnkasOujiGame game = new OnkasOujiGame(nft_onkas, token_gold, pyth_entropy, pyth_provider, randomizer, [SAV_PK_X, SAV_PK_Y], vm.addr(marketing));
        // grant roles to operator, sav prover
        game.grantRoles(operator, ROLE_OPERATOR);
        game.grantRoles(sav_prover, ROLE_SAV_PROVER);

        vm.stopBroadcast();

        save_deployment("game_contract", address(game), "gold_contract", address(token_gold), "onkas_contract", address(nft_onkas));
        return game;
    }

    function save_deployment(string memory mainLabel, address main, string memory tokenLabel, address token, string memory nftLabel, address nft)
        internal
    {
        string memory deployment = string.concat(
            "{",
            '"network": "',
            vm.toString(block.chainid),
            '",',
            string.concat('"', mainLabel, '":"', vm.toString(main), '"'),
            ',',
            string.concat('"', tokenLabel, '":"', vm.toString(token), '"'),
            ',',
            string.concat('"', nftLabel, '":"', vm.toString(nft), '"'),
            "}"
        );

        vm.writeFile("./out/deployments.json", deployment);
    }
}
