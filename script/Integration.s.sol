// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.26;

import {SetupScript} from "./Setup.s.sol";
import {console} from "forge-std/console.sol";
import {Player, GameData, TestGameTypes, GameStatus} from "../src/lib/models.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Vm} from "forge-std/Vm.sol";

contract IntegrationScript is SetupScript {
    // Test constants
    uint256 constant STANDARD_GAME_AMOUNT = 100 ether;
    uint256 constant STANDARD_BET_AMOUNT = 50 ether;

    event GameStateChanged(uint256 gameId, GameStatus state);

    function run() public override {
        super.run();
        console.log("\n=== Starting Integration Tests ===\n");

        // testGameCreation();
        /// testInvalidNFTOwnership();
        // testBetting();
        testGameFlow();
        // testGameAbortion();
        // testAccessControl();
        /// testEdgeCases();
        // testGameEvents();

        console.log("\n=== Integration Tests Completed ===\n");
    }

    function testGameCreation() public {
        console.log("\n--- Test: Game Creation ---");
        vm.startBroadcast(deployer);

        console.log("Creating basic game...");
        uint256 gameId = createBasicGame();
        GameData memory game = mainContract.get_game(gameId);
        assert(game.status == GameStatus.OPEN);
        console.log("Game created successfully with ID:", gameId);
        console.log("Game state:", uint256(game.status));
        console.log("Game amount:", _to_token_str(game.amount), "tGOLD");

        vm.stopBroadcast();
        console.log("SUCCESS Game Creation test passed");
    }

    function testInvalidNFTOwnership() public {
        console.log("\n--- Test: Invalid NFT Ownership ---");
        vm.startBroadcast(deployer);

        console.log("Attempting to create game with invalid NFT ID...");
        Player[2] memory invalidPlayers = [Player(vm.addr(test_wallets[0]), 999), Player(vm.addr(test_wallets[1]), 3)];

        try mainContract.new_game(invalidPlayers, STANDARD_GAME_AMOUNT) {
            console.log("FAIL Test failed: Should have reverted");
            assert(false);
        } catch {
            console.log("SUCCESS Successfully caught invalid NFT ownership");
        }

        vm.stopBroadcast();
        console.log("SUCCESS Invalid NFT Ownership test passed");
    }

    function testBetting() public {
        console.log("\n--- Test: Betting Functionality ---");
        vm.startBroadcast(deployer);

        console.log("Creating game for betting test...");
        uint256 gameId = createBasicGame();
        address bettor = vm.addr(test_wallets[2]);

        console.log("Placing valid bet...");
        uint256 initialBalance = testToken.balanceOf(bettor);
        mainContract.place_bet(gameId, bettor, 0, STANDARD_BET_AMOUNT);
        console.log("Bet placed successfully");
        console.log("Initial balance:", _to_token_str(initialBalance));
        console.log("New balance:", _to_token_str(testToken.balanceOf(bettor)));

        // console.log("Testing invalid bet scenarios...");
        // try mainContract.place_bet(999, bettor, 0, STANDARD_BET_AMOUNT) {
        //     assert(false);
        // } catch {
        //     console.log("SUCCESS Successfully caught invalid game ID bet");
        // }

        // try mainContract.place_bet(gameId, bettor, 2, STANDARD_BET_AMOUNT) {
        //     assert(false);
        // } catch {
        //     console.log("SUCCESS Successfully caught invalid prediction value");
        // }

        vm.stopBroadcast();
        console.log("SUCCESS Betting test passed");
    }

    // function testGameFlow() public {
    //     console.log("\n--- Test: Game Flow ---");
    //     vm.startBroadcast(deployer);

    //     console.log("Creating game and placing bets...");
    //     uint256 gameId = createBasicGame();
    //     address bettor1 = vm.addr(test_wallets[2]);
    //     address bettor2 = vm.addr(test_wallets[3]);

    //     mainContract.place_bet(gameId, bettor1, 0, STANDARD_BET_AMOUNT);
    //     mainContract.place_bet(gameId, bettor2, 1, STANDARD_BET_AMOUNT);
    //     console.log("Bets placed successfully");

    //     console.log("Starting game with entropy fee...");
    //     mainContract.start_game{value: 0.1 ether}(gameId);

    //     GameData memory game = mainContract.get_game(gameId);
    //     console.log("Game state after start:", uint(game.status));
    //     assert(game.status == GameStatus.ACTIVE);

    //     vm.stopBroadcast();
    //     console.log("SUCCESS Game Flow test passed");
    // }
    // function testGameFlow() public {
    //     console.log("\n--- Test: Complete Game Flow ---");

    //     // Create game
    //     vm.startBroadcast(deployer);
    //     uint256 gameId = createBasicGame();
    //     address bettor1 = vm.addr(test_wallets[2]);
    //     address bettor2 = vm.addr(test_wallets[3]);

    //     // Place bets
    //     mainContract.place_bet(gameId, bettor1, 0, STANDARD_BET_AMOUNT);
    //     mainContract.place_bet(gameId, bettor2, 1, STANDARD_BET_AMOUNT);

    //     // Record initial balances
    //     uint256 bettor1InitialBalance = testToken.balanceOf(bettor1);
    //     uint256 bettor2InitialBalance = testToken.balanceOf(bettor2);
    //     console.log("Initial balances recorded");

    //     // Start game
    //     console.log("Starting game with entropy fee...");
    //     mainContract.start_game{value: 0.1 ether}(gameId);
    //     vm.stopBroadcast();

    //     // Simulate entropy callback
    //     console.log("Simulating entropy callback...");
    //     uint256 randomNumber = 12345; // Example random number
    //     vm.startBroadcast(entropyProvider);
    //     mainContract.entropyCallback(gameId, randomNumber);
    //     vm.stopBroadcast();

    //     // Check game completion
    //     vm.startBroadcast(deployer);
    //     GameData memory game = mainContract.get_game(gameId);
    //     console.log("Game state after entropy:", uint256(game.status));
    //     assert(game.status == GameStatus.COMPLETED);

    //     // Check winner payouts
    //     uint256 bettor1FinalBalance = testToken.balanceOf(bettor1);
    //     uint256 bettor2FinalBalance = testToken.balanceOf(bettor2);
    //     console.log("Final balances checked");

    //     // Verify either bettor1 or bettor2 won (depending on random number)
    //     bool someoneWon = (bettor1FinalBalance > bettor1InitialBalance) || (bettor2FinalBalance > bettor2InitialBalance);
    //     assert(someoneWon);
    //     vm.stopBroadcast();

    //     console.log("SUCCESS Complete Game Flow test passed");
    // }
    function testGameFlow() public {
        console.log("\n--- Test: Game Flow ---");
        vm.startBroadcast(deployer);

        console.log("Creating game and placing bets...");
        uint256 gameId = createBasicGame();
        // GameData memory g2 = mainContract.get_game(2);
        // console.log("Game ID:", Strings .toString(2));
        // console.log("Game state:", uint256(g2.state));
        // console.log("Game amount:", _to_token_str(g2.amount));
        // console.log("Game prediction1:", g2.speculations[0].prediction);
        // console.log("Game prediction1 amt:", g2.speculations[0].amount);
        // console.log("Game p1 wins:", g2.player1Wins);
        // console.log("Game p2 wins:", g2.player2Wins);
        // console.log("Game winner:", g2.player1Wins > g2.player2Wins ? "Player 1" : "Player 2");
        // console.log("Game player1 address:", g2.players[0].addr);
        // console.log("Game player1 onka id:", g2.players[0].nft_id);
        // console.log("Game player2 address:", g2.players[1].addr);
        // console.log("Game player2 onka id:", g2.players[1].nft_id);
        // uint256 gameId = 2;
        address bettor1 = vm.addr(test_wallets[2]);
        address bettor2 = vm.addr(test_wallets[3]);

        mainContract.place_bet(gameId, bettor1, 0, STANDARD_BET_AMOUNT);
        mainContract.place_bet(gameId, bettor2, 1, STANDARD_BET_AMOUNT);
        console.log("Bets placed successfully");

        console.log("Starting game with entropy fee...");
        mainContract.start_game{value: 0.1 ether}(gameId);

        GameData memory game = mainContract.get_game(gameId);
        console.log("Game state after start:", uint256(game.status));
        assert(game.status == GameStatus.ACTIVE);

        console.log("Game started successfully - waiting for external entropy callback...");
        console.log("Game ID for manual verification:", gameId);

        vm.stopBroadcast();
        console.log("SUCCESS Game Flow test passed (pending entropy callback)");
    }

    // function testInvalidOperations() public {
    //     console.log("\n--- Test: Invalid Operations ---");

    //     uint256 gameId = createBasicGame();
    //     address unauthorized = vm.addr(test_wallets[4]);

    //     // Test invalid NFT ownership (outside broadcast)
    //     Player[2] memory invalidPlayers = [Player(vm.addr(test_wallets[0]), 999), Player(vm.addr(test_wallets[1]), 3)];

    //     vm.startBroadcast(deployer);
    //     bool caught = false;
    //     try mainContract.new_game(invalidPlayers, STANDARD_GAME_AMOUNT) {
    //         console.log("FAIL Should have reverted on invalid NFT");
    //     } catch {
    //         caught = true;
    //     }
    //     vm.stopBroadcast();
    //     assert(caught);

    //     // Test unauthorized game start
    //     vm.startBroadcast(unauthorized);
    //     caught = false;
    //     try mainContract.start_game{value: 0.1 ether}(gameId) {
    //         console.log("FAIL Should have reverted on unauthorized start");
    //     } catch {
    //         caught = true;
    //     }
    //     vm.stopBroadcast();
    //     assert(caught);

    //     // Test invalid entropy callback
    //     vm.startBroadcast(unauthorized);
    //     caught = false;
    //     try mainContract.entropyCallback(gameId, 12345) {
    //         console.log("FAIL Should have reverted on unauthorized entropy callback");
    //     } catch {
    //         caught = true;
    //     }
    //     vm.stopBroadcast();
    //     assert(caught);

    //     console.log("SUCCESS Invalid Operations test passed");
    // }

    function testGameAbortion() public {
        console.log("\n--- Test: Game Abortion ---");
        vm.startBroadcast(deployer);

        uint256 gameId = createBasicGame();
        address bettor = vm.addr(test_wallets[2]);

        console.log("Initial bettor balance:", _to_token_str(testToken.balanceOf(bettor)));
        mainContract.place_bet(gameId, bettor, 0, STANDARD_BET_AMOUNT);
        uint256 initialBettorBalance = testToken.balanceOf(bettor);
        console.log("Balance after betting:", _to_token_str(initialBettorBalance));

        console.log("Aborting game...");
        mainContract.abort_game(gameId);

        uint256 finalBalance = testToken.balanceOf(bettor);
        console.log("Final balance after abort:", _to_token_str(finalBalance));
        assert(finalBalance == initialBettorBalance + STANDARD_BET_AMOUNT);

        GameData memory game = mainContract.get_game(gameId);
        assert(game.status == GameStatus.CANCELLED);

        vm.stopBroadcast();
        console.log("SUCCESS Game Abortion test passed");
    }

    function testAccessControl() public {
        console.log("\n--- Test: Access Control ---");
        address operator_addr = vm.addr(deployer);
        vm.startBroadcast(deployer);

        uint256 operatorRole = mainContract.ROLE_OPERATOR();
        console.log("Checking operator role...");
        assert(mainContract.rolesOf(operator_addr) == operatorRole);
        console.log("Operator role confirmed for:", operator_addr);
        vm.stopBroadcast();

        // console.log("Testing unauthorized access...");
        // address unauthorized = vm.addr(test_wallets[0]);
        // vm.startBroadcast(unauthorized);
        // try mainContract.abort_game(1) {
        //     assert(false);
        // } catch {
        //     console.log("SUCCESS Successfully prevented unauthorized access");
        // }
        // vm.stopBroadcast();

        console.log("SUCCESS Access Control test passed");
    }

    function testEdgeCases() public {
        console.log("\n--- Test: Edge Cases ---");
        vm.startBroadcast(deployer);

        uint256 gameId = createBasicGame();
        address bettor = vm.addr(test_wallets[2]);

        console.log("Testing zero amount bet...");
        try mainContract.place_bet(gameId, bettor, 0, 0) {
            assert(false);
        } catch {
            console.log("SUCCESS Successfully caught zero amount bet");
        }

        console.log("Testing maximum bet amount...");
        try mainContract.place_bet(gameId, bettor, 0, type(uint256).max) {
            assert(false);
        } catch {
            console.log("SUCCESS Successfully caught maximum bet amount");
        }

        vm.stopBroadcast();
        console.log("SUCCESS Edge Cases test passed");
    }

    function testGameEvents() public {
        console.log("\n--- Test: Game Events ---");

        vm.recordLogs();

        vm.startBroadcast(deployer);
        uint256 gameId = createBasicGame();
        mainContract.start_game{value: 0.1 ether}(gameId);
        vm.stopBroadcast();

        // vm.startBroadcast(entropyProvider);
        // mainContract.entropyCallback(gameId, 12345);
        // vm.stopBroadcast();

        Vm.Log[] memory entries = vm.getRecordedLogs();
        bool foundOpenEvent = false;
        bool foundActiveEvent = false;
        bool foundCompletedEvent = false;

        for (uint256 i = 0; i < entries.length; i++) {
            // Check if it's our GameStateChanged event
            if (entries[i].topics[0] == keccak256("GameStateChanged(uint256,uint8)")) {
                uint256 eventGameId = uint256(entries[i].topics[1]);
                uint8 state = uint8(uint256(entries[i].topics[2]));

                if (eventGameId == gameId) {
                    if (state == uint8(GameStatus.OPEN)) foundOpenEvent = true;
                    if (state == uint8(GameStatus.ACTIVE)) foundActiveEvent = true;
                    if (state == uint8(GameStatus.COMPLETED)) foundCompletedEvent = true;
                }
            }
        }

        // assert(foundOpenEvent && foundActiveEvent && foundCompletedEvent);
        console.log("foundOpenEvent =", foundOpenEvent);
        console.log("foundActiveEvent =", foundActiveEvent);
        console.log("foundCompletedEvent =", foundCompletedEvent);
        console.log("UNKNOWN Game Events test completed");
    }

    // Helper functions
    function createBasicGame() internal returns (uint256) {
        Player[2] memory players = [Player(vm.addr(test_wallets[0]), 2), Player(vm.addr(test_wallets[1]), 3)];
        mainContract.new_game(players, STANDARD_GAME_AMOUNT);
        return mainContract.get_current_game_id();
    }

    function _cointoss(uint256 dimension) internal view returns (uint256) {
        return block.number % dimension;
    }

    function _confirm_ownership(address player, uint256 onka_id) internal view {
        address owner = testNFT.ownerOf(onka_id);
        assert(owner == player);
    }

    function _to_token_str(uint256 amount) internal pure returns (string memory) {
        return string.concat(Strings.toString(amount / 1e18), ".", Strings.toString((amount % 1e18) / 1e16));
    }
}
