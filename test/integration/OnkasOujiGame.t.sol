// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {Wyrd} from "src/Wyrd.sol";
import {OnkasOujiGame} from "src/OnkasOujiGame.sol";
import {GameData, GameStatus, Player, Speculation, RoundResult, OnkaStats} from "src/lib/models.sol";

import {VRFTestData} from "test/utils/VRFTestData.sol";
import "test/config.sol" as cfg;
import {OnkasOujiGameTestHelpers, TestableOnkasOujiGame} from "test/integration/Helpers.t.sol";

import {MockPythEntropy, MockRandomizer} from "test/mocks/MockRandomProviders.t.sol";
import {TestNFT} from "test/mocks/MockERC721.t.sol";
import {TestERC20} from "test/mocks/MockERC20.t.sol";
import {WyrdTests} from "test/integration/Wyrd.t.sol";

contract OnkasOujiGameIntegrationTest is OnkasOujiGameTestHelpers {
    // Test accounts
    address private owner;
    address private player1;
    address private player2;
    address private bettor1;
    address private bettor2;
    address private marketing_wallet;

    // Onka NFT IDs
    uint256 private onka_p1;
    uint256 private onka_p2;
    uint256 private onka_p3;
    uint256 private onka_p4;

    function setUp() public {
        // Initialize test accounts and mock contracts
        // Deploy OnkasOujiGame with mocks
        // Mint NFTs to players
        // Mint tokens to players and bettors
        //

        // Label addresses for easier debugging
        vm.label(cfg.ADDR_DEPLOYER, "Deployer"); // TODO: play around with cheatcodes more
        vm.label(cfg.ADDR_OPERATOR, "Operator");
        vm.label(cfg.ADDR_PLAYER_1, "Player1");
        vm.label(cfg.ADDR_PLAYER_2, "Player2");
        vm.label(cfg.ADDR_PLAYER_3, "Player3");
        vm.label(cfg.ADDR_PLAYER_4, "Player4");
        vm.label(cfg.ADDR_BETOOR_1, "Bettor1");
        vm.label(cfg.ADDR_BETOOR_2, "Bettor2");
        vm.label(cfg.ADDR_BETOOR_3, "Bettor3");
        vm.label(cfg.ADDR_MARKETING, "Marketing");
        vm.label(cfg.ADDR_PYTH_PROVIDER, "PythProvider");

        vm.deal(cfg.ADDR_OPERATOR, 100 ether);

        pyth_entropy = new MockPythEntropy();
        randomizer = new MockRandomizer();
        mock_pyth_entropy = pyth_entropy;
        mock_randomizer = randomizer;

        // Tokens: $GOLD & $ONKA
        //
        vm.startPrank(cfg.ADDR_DEPLOYER);
        nft = new TestNFT(); // address(this) should recieve 90B
        token = new TestERC20();

        // Mint NFTs
        onka_p1 = nft.mint(cfg.ADDR_PLAYER_1);
        onka_p2 = nft.mint(cfg.ADDR_PLAYER_2);
        onka_p3 = nft.mint(cfg.ADDR_PLAYER_3);
        onka_p4 = nft.mint(cfg.ADDR_PLAYER_4);

        // Mint tokens to players, betoors
        token.mint(cfg.ADDR_PLAYER_1, 1000 ether);
        token.mint(cfg.ADDR_PLAYER_2, 1000 ether);
        token.mint(cfg.ADDR_PLAYER_3, 1000 ether);
        token.mint(cfg.ADDR_PLAYER_4, 1000 ether);
        token.mint(cfg.ADDR_BETOOR_1, 1000 ether);
        token.mint(cfg.ADDR_BETOOR_2, 1000 ether);
        token.mint(cfg.ADDR_BETOOR_3, 1000 ether);
        token.mint(cfg.ADDR_BETOOR_4, 1000 ether);
        token.mint(cfg.ADDR_BETOOR_5, 1000 ether);
        token.mint(cfg.ADDR_BETOOR_6, 1000 ether);
        token.mint(cfg.ADDR_BETOOR_7, 1000 ether);
        token.mint(cfg.ADDR_BETOOR_8, 1000 ether);
        token.mint(cfg.ADDR_BETOOR_9, 1000 ether);

        // Deploy: Game
        //
        uint256[2] memory sav_pk = [uint256(0x1), uint256(0x2)];
        game = new TestableOnkasOujiGame(
            address(nft), address(token), address(pyth_entropy), cfg.ADDR_PYTH_PROVIDER, address(randomizer), sav_pk, cfg.ADDR_MARKETING
        );
        wyrd = game;
        twyrd = game;
        sav_pk = twyrd.vrf_tester().get_pk();
        vm.stopPrank();
        // post-deployment setup
        grant_roles(address(game), cfg.ADDR_OPERATOR, ROLE_OPERATOR);
        grant_roles(address(game), cfg.ADDR_SAV_PROVER, ROLE_SAV_PROVER);
        sav_update_public_key();
    }

    // Test full game flow - from creation to completion
    function t7est_complete_game_flow() public {
        // 1. Register players
        // 2. Create a new game
        // 3. Place bets from multiple bettors
        // 4. Start game
        // 5. Execute game (simulate randomness callback)
        // 6. Complete game and verify payouts
        // 7. Check balances of all participants
        // 8. Verify NFT stats are updated

        // Use run_game to start a game between Player1 and Player2 with 3 bets
        // Setup players and speculators
        Player[2] memory players = [Player(cfg.ADDR_PLAYER_1, onka_p1), Player(cfg.ADDR_PLAYER_2, onka_p2)];

        // Create 3 speculation structures for bettors
        Speculation[] memory speculations = new Speculation[](3);
        speculations[0] = Speculation(cfg.ADDR_BETOOR_1, true, 5 ether); // Bettor1 betting on Player1
        speculations[1] = Speculation(cfg.ADDR_BETOOR_2, false, 7 ether); // Bettor2 betting on Player2
        speculations[2] = Speculation(cfg.ADDR_BETOOR_3, true, 3 ether); // Bettor3 betting on Player1

        // Start the game with players and speculations
        uint256 game_id = setup_game(players, GAME_AMOUNT, speculations, true);

        // Record balances before finishing the game
        uint256 player1_balance_before = token.balanceOf(cfg.ADDR_PLAYER_1);
        uint256 player2_balance_before = token.balanceOf(cfg.ADDR_PLAYER_2);
        uint256 bettor1_balance_before = token.balanceOf(cfg.ADDR_BETOOR_1);
        uint256 bettor2_balance_before = token.balanceOf(cfg.ADDR_BETOOR_2);
        uint256 bettor3_balance_before = token.balanceOf(cfg.ADDR_BETOOR_3);
        uint256 marketing_balance_before = token.balanceOf(cfg.ADDR_MARKETING);

        // Start the game and prepare for randomness
        vm.startPrank(cfg.ADDR_OPERATOR);
        (uint256 request_fee,,) = game.calc_fee();
        game.start_game{value: request_fee}(game_id);

        // Simulate randomness callback with a value that Player1 will win
        // Set entropy for PLAYER1 WIN (first player wins if first roll is higher)
        game.exec_game(game_id);
        game.end_game(game_id);
        vm.stopPrank();

        // Verify game is complete
        GameData memory completed_game = game.get_game(game_id);
        assertEq(uint8(completed_game.status), uint8(GameStatus.COMPLETED), "Game should be completed");

        // Check NFT stats are updated
        // OnkaStats memory p1_stats = game.get_onka_stats(onka_p1);
        // OnkaStats memory p2_stats = game.get_onka_stats(onka_p2);
        // assertEq(p1_stats.plays, 1, "Player1 NFT should have 1 play");
        // assertEq(p2_stats.plays, 1, "Player2 NFT should have 1 play");

        // Verify game no longer in active games list
        uint256[] memory active_games = game.get_active_game_ids();
        bool game_still_active = false;
        for (uint256 i = 0; i < active_games.length; i++) {
            if (active_games[i] == game_id) {
                game_still_active = true;
                break;
            }
        }
        assertFalse(game_still_active, "Game should be removed from active games");

        // Check appropriate balances after game completion
        console.log("Checking final balances after game completion");
        // Note: specific balance checks would depend on game outcome and revenue sharing settings
    }

    // Test user registration and game creation
    function test_register_and_create_game() public {
        // Register player 1
        register_user(cfg.ADDR_PLAYER_1, bytes32("secret_PLAYER_1"));

        // Register player 2
        register_user(cfg.ADDR_PLAYER_2, bytes32("secret_PLAYER_2"));

        // Player 3: failed registration
        vm.startPrank(cfg.ADDR_PLAYER_3);
        vm.deal(cfg.ADDR_PLAYER_3, 0.1 ether);
        token.approve(address(game), type(uint256).max - 1);
        vm.expectRevert();
        game.register(bytes32("secret_PLAYER_3"));
        vm.stopPrank();

        // Player 4: unregistered (Approve but don't register player 4)
        vm.startPrank(cfg.ADDR_PLAYER_4);
        vm.deal(cfg.ADDR_PLAYER_4, 0.1 ether);
        token.approve(address(game), 5);
        // game.register(bytes32("secret_PLAYER_4"));
        vm.stopPrank();

        // Test new game creation - create a game between player1 and player2 with 10 ether stake
        // This will check event emission, token transfers, and game state initialization

        create_game_and_verify_balances([Player(cfg.ADDR_PLAYER_1, onka_p1), Player(cfg.ADDR_PLAYER_2, onka_p2)], 10 ether, 1);

        // 1. Test with non-registered user (Player 4 isn't registered, but as long as sufficient approval exists, game creation should succeed)
        create_game_and_verify_balances([Player(cfg.ADDR_PLAYER_1, onka_p1), Player(cfg.ADDR_PLAYER_4, onka_p4)], 5, 2, bytes32(uint256(0x1338)));

        // Test game creation failure scenarios

        // 2. Test with registered user with insufficient balance
        // Drain player2's account leaving only 5 ether
        set_user_token_balance(cfg.ADDR_PLAYER_2, 5 ether);

        vm.startPrank(cfg.ADDR_OPERATOR);
        vm.expectRevert();
        game.new_game([Player(cfg.ADDR_PLAYER_1, onka_p1), Player(cfg.ADDR_PLAYER_2, onka_p2)], 10 ether, bytes32(uint256(0x1339)));
        vm.stopPrank();

        // 3. Test with user that doesn't own the specified NFT
        vm.startPrank(cfg.ADDR_OPERATOR);
        vm.expectRevert(abi.encodeWithSelector(OnkasOujiGame.InvalidNFTOwnership.selector, cfg.ADDR_PLAYER_1, onka_p2));
        game.new_game([Player(cfg.ADDR_PLAYER_1, onka_p2), Player(cfg.ADDR_PLAYER_2, onka_p1)], 10 ether, bytes32(uint256(0x1340)));
        vm.stopPrank();

        // 4. Test with non-operator address calls
        vm.startPrank(address(0xCAFE));
        vm.expectRevert();
        game.new_game([Player(cfg.ADDR_PLAYER_1, onka_p1), Player(cfg.ADDR_PLAYER_2, onka_p2)], 10 ether, bytes32(uint256(0x1341)));
        vm.stopPrank();
    }

    // Test game abortion
    function test_abort_game() public {
        uint256 amount = 10 ether;
        uint256 bet = 5 ether;

        // Setup: register users which also approves tokens
        address[] memory users = new address[](3);
        users[0] = cfg.ADDR_PLAYER_1;
        users[1] = cfg.ADDR_PLAYER_2;
        users[2] = cfg.ADDR_BETOOR_1;
        register_users(users);

        // vars
        uint256 game_id;
        GameData memory game_data;
        Balance[] memory expected_bals = new Balance[](3);
        uint256 player1_initial_balance = token.balanceOf(cfg.ADDR_PLAYER_1);
        uint256 player2_initial_balance = token.balanceOf(cfg.ADDR_PLAYER_2);
        uint256 bettor1_initial_balance = token.balanceOf(cfg.ADDR_BETOOR_1);

        // verify starting balances
        expected_bals[0] = Balance(cfg.ADDR_PLAYER_1, player1_initial_balance);
        expected_bals[1] = Balance(cfg.ADDR_PLAYER_2, player2_initial_balance);
        expected_bals[2] = Balance(cfg.ADDR_BETOOR_1, bettor1_initial_balance);
        verify_balances(expected_bals);

        // New Game Abort: a new game
        //
        game_id = create_game_and_verify_balances([Player(cfg.ADDR_PLAYER_1, onka_p1), Player(cfg.ADDR_PLAYER_2, onka_p2)], amount, 1);
        //abort
        abort_game(game_id);
        verify_balances(expected_bals); // expect refund
        verify_game_not_active(game_id);

        // Bets Abort: place a bet and then abort the game
        //
        game_id = create_game_and_verify_balances([Player(cfg.ADDR_PLAYER_1, onka_p1), Player(cfg.ADDR_PLAYER_2, onka_p2)], amount, game_id + 1);
        place_bet_and_verify_balances(game_id, cfg.ADDR_BETOOR_1, true, bet);
        game_data = game.get_game(game_id);
        // abort
        abort_game(game_id);
        verify_balances(expected_bals);
        verify_game_not_active(game_id);

        // In-Progress Abort: start a game and abort after it starts
        //
        for (uint8 i = 0; i < 2; i++) {
            game_id = create_game_and_verify_balances([Player(cfg.ADDR_PLAYER_1, onka_p1), Player(cfg.ADDR_PLAYER_2, onka_p2)], amount, game_id + 1);
            if (i == 1) place_bet_and_verify_balances(game_id, cfg.ADDR_BETOOR_1, true, bet);
            start_game_and_verify_balances(game_id);
            // abort
            abort_game(game_id);
            verify_balances(expected_bals);
            verify_game_not_active(game_id);
        }

        // Post-exec abort: Test aborting a game that's in progress and has computed results
        //
        game_id = create_game_and_verify_balances([Player(cfg.ADDR_PLAYER_1, onka_p1), Player(cfg.ADDR_PLAYER_2, onka_p2)], amount, game_id + 1);
        start_game_and_verify_balances(game_id);
        // process cbs
        ext_process_request_callbacks(game_id);
        // exec
        exec_game(game_id);
        // abort
        abort_game(game_id);
        verify_balances(expected_bals);
        verify_game_not_active(game_id);
    }

    // Test betting mechanics and odds calculation
    function test_betting_mechanics() public {
        // Register all necessary users
        address[] memory users = new address[](4);
        users[0] = cfg.ADDR_PLAYER_1;
        users[1] = cfg.ADDR_PLAYER_2;
        users[2] = cfg.ADDR_BETOOR_1;
        users[3] = cfg.ADDR_BETOOR_2;
        register_users(users);

        uint256 amount = 10 ether;
        uint256 game_id = create_game_and_verify_balances([Player(cfg.ADDR_PLAYER_1, onka_p1), Player(cfg.ADDR_PLAYER_2, onka_p2)], amount, 1);

        // Test 1: Basic bet placement
        uint256 bet_amount1 = 5 ether;
        place_bet_and_verify_balances(game_id, cfg.ADDR_BETOOR_1, true, bet_amount1);
        verify_bet_pool_state(game_id, bet_amount1, bet_amount1, 0);

        // Test 2: Second bet on same side
        uint256 bet_amount2 = 3 ether;
        place_bet_and_verify_balances(game_id, cfg.ADDR_BETOOR_2, true, bet_amount2);
        verify_bet_pool_state(game_id, bet_amount1 + bet_amount2, bet_amount1 + bet_amount2, 0);

        // Test 3: Bet on opposite side
        uint256 bet_amount3 = 7 ether;
        place_bet_and_verify_balances(game_id, cfg.ADDR_BETOOR_2, false, bet_amount3);
        verify_bet_pool_state(game_id, bet_amount1 + bet_amount2 + bet_amount3, bet_amount1 + bet_amount2, bet_amount3);

        // Test 4: Betting after game starts should fail
        start_game_and_verify_balances(game_id);

        vm.startPrank(cfg.ADDR_OPERATOR);
        vm.expectRevert();
        game.place_bet(game_id, cfg.ADDR_BETOOR_1, true, 1 ether);
        vm.stopPrank();

        // Test 5: Complete game flow with bets and verify payouts
        // Abort current game first
        abort_game(game_id);

        // bets
        Speculation[] memory speculations = new Speculation[](2);
        speculations[0] = Speculation(cfg.ADDR_BETOOR_1, true, 5 ether); // Bet on P1
        speculations[1] = Speculation(cfg.ADDR_BETOOR_2, false, 7 ether); // Bet on P2

        // Record balances before game completion
        uint256 player1_balance_before = token.balanceOf(cfg.ADDR_PLAYER_1);
        uint256 player2_balance_before = token.balanceOf(cfg.ADDR_PLAYER_2);
        uint256 bettor1_balance_before = token.balanceOf(cfg.ADDR_BETOOR_1);
        uint256 bettor2_balance_before = token.balanceOf(cfg.ADDR_BETOOR_2);
        uint256 marketing_balance_before = token.balanceOf(cfg.ADDR_MARKETING);

        // Create new game
        game_id = setup_game_with_bets([Player(cfg.ADDR_PLAYER_1, onka_p1), Player(cfg.ADDR_PLAYER_2, onka_p2)], amount, speculations);
        // Complete game using helper
        complete_created_game_flow(game_id);

        // Verify balances after game completion
        GameData memory game_data = game.get_game(game_id);
        bool player1_won = game_data.p1_wins > game_data.p2_wins;

        // Calculate expected payouts using helper
        (uint256 marketing_share,uint256 p_win_share, uint256 bettor_p1_share,) = calculate_expected_payouts(game_id);

        if (player1_won) {
            assertEq(token.balanceOf(cfg.ADDR_PLAYER_1), player1_balance_before - amount + p_win_share, "Player1 should receive winnings");
            assertEq(token.balanceOf(cfg.ADDR_BETOOR_1), bettor1_balance_before - 5 ether + bettor_p1_share, "Bettor1 should receive winnings");
        } else {
            assertEq(token.balanceOf(cfg.ADDR_PLAYER_2), player2_balance_before - amount + p_win_share, "Player2 should receive winnings");
        }

        // Marketing should always receive its share
        assertEq(token.balanceOf(cfg.ADDR_MARKETING), marketing_balance_before + marketing_share, "Marketing should receive fee");
    }

    // Test revenue sharing
    function test_revenue_sharing() public {
        // Complete a game with bets
        // Verify marketing wallet receives the correct percentage
    }

    // Test randomness and game execution
    function test_game_randomness() public {
        // Create and start multiple games
        // Provide different random values
        // Verify different outcomes
    }

    // Test input validation
    function test_input_validation() public {
        // Try to create games with invalid inputs
        // Verify appropriate errors are thrown
    }

    // Test player verification
    function test_player_nft_verification() public {
        // Try to create game with NFTs not owned by players
        // Verify appropriate errors are thrown
    }

    // Test role-based access control
    function test_access_control() public {
        // Try to call restricted functions from unauthorized accounts
        // Verify appropriate errors are thrown
    }

    // Test edge cases
    function test_edge_cases() public {
        // Test one-sided betting pools
        // Test tie scenarios in game rounds
        // Test maximum values for bets
    }
}
