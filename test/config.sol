// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.28;

import {VRFTestData} from "./utils/VRFTestData.sol";

uint8 constant FLAG_ALL_SOURCES = 7;
uint8 constant FLAG_NONE = 0;
uint8 constant FLAG_PYTH = 1;
uint8 constant FLAG_RANDOMIZER = 2;
uint8 constant FLAG_SAV = 4;

// roles
address constant ADDR_DEPLOYER = address(0x1337F000);
address constant ADDR_OPERATOR = address(0x1337F001);

// providers
address constant ADDR_RANDOMIZER = address(0x1337F002); // wont be used unless etching w/cheatcode
address constant ADDR_SAV_PROVER = address(0x1337F003);
address constant ADDR_PYTH_ENTROPY = address(0x1337F004); // wont be used unless etching w/cheatcode
address constant ADDR_PYTH_PROVIDER = address(0x1337F005);
// address constant ADDR_RANDOMIZER = 0xe360c1285E2ECB36C16faFa62e86B30AB5fb7dB3;
// address constant ADDR_PYTH_ENTROPY = 0x5744Cbf430D99456a0A8771208b674F27f8EF0Fb;
// address constant ADDR_PYTH_PROVIDER = 0x6CC14824Ea2918f5De5C2f75A9Da968ad4BD6344;
// bytes32 constant SAV_PROVER_SK = VRFTestData.SECRET_KEY;
// uint256 constant SAV_PROVER_PK_X = VRFTestData.PUBLIC_KEY_X;
// uint256 constant SAV_PROVER_PK_Y = VRFTestData.PUBLIC_KEY_Y;

// players
address constant ADDR_PLAYER_1 = address(0xBEE75001);
address constant ADDR_PLAYER_2 = address(0xBEE75002);
address constant ADDR_PLAYER_3 = address(0xBEE75003);
address constant ADDR_PLAYER_4 = address(0xBEE75004);
address constant ADDR_BETOOR_1 = address(0xBEE75005);
address constant ADDR_BETOOR_2 = address(0xBEE75006);
address constant ADDR_BETOOR_3 = address(0xBEE75007);
address constant ADDR_BETOOR_4 = address(0xBEE75008);
address constant ADDR_BETOOR_5 = address(0xBEE75009);
address constant ADDR_BETOOR_6 = address(0xBEE75010);
address constant ADDR_BETOOR_7 = address(0xBEE75011);
address constant ADDR_BETOOR_8 = address(0xBEE75012);
address constant ADDR_BETOOR_9 = address(0xBEE75013);
address constant ADDR_MARKETING = address(0xBEE75999);
