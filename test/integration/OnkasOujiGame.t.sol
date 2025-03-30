// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {FixedPointMathLib as FPML} from "solady/utils/FixedPointMathLib.sol";
import {Wyrd} from "src/Wyrd.sol";
import {OnkasOujiGame} from "src/OnkasOujiGame.sol";
import {GameData, GameStatus, Player, Speculation, RoundResult, OnkaStats} from "src/lib/models.sol";

import {VRFTestData} from "test/utils/VRFTestData.sol";
import "test/config.sol" as cfg;
import {OnkasOujiGameTestHelpers, TestableOnkasOujiGame, BaseBet, Balance} from "test/integration/Helpers.t.sol";

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
    function test_complete_game_flow() public {
        // 1. Register players
        // 2. Create a new game
        // 3. Place bets from multiple bettors
        // 4. Start game
        // 5. Execute game (simulate randomness callback)
        // 6. Complete game and verify payouts
        // 7. Check balances of all participants
        // 8. Verify NFT stats are updated (TODO: not implemented here)

        uint256 amount = 13 ether + 37 gwei;
        uint256 bet = 17 ether + 53 gwei;

        // Setup: register users which also approves tokens
        address[] memory users = new address[](2);
        users[0] = cfg.ADDR_PLAYER_1;
        users[1] = cfg.ADDR_PLAYER_2;
        register_users(users);

        // prep helper struct values
        BaseBet[] memory bets = new BaseBet[](1);
        bets[0] = BaseBet({amount: bet, side: true});
        uint256[] memory onkas = new uint256[](2);
        onkas[0] = onka_p1;
        onkas[1] = onka_p2;

        // run game (see helper fn for mock/implementation reference)
        run_game_with_values(amount, bets, onkas);
    }

    // Test user registration and game creation
    function test_register_and_create_game() public {
        // Register players
        register_user(cfg.ADDR_PLAYER_1, bytes32("secret_PLAYER_1"));
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

        uint256[] memory onkas = new uint256[](2);
        onkas[0] = onka_p1;
        onkas[1] = onka_p2;

        uint256 amount = 10 ether;

        // Test 1A: One-Sided bet placement
        // uint256 bet_amount1 = 5 ether;
        // place_bet_and_verify_balances(game_id, cfg.ADDR_BETOOR_1, true, bet_amount1);
        // verify_bet_pool_state(game_id, bet_amount1, 0,bet_amount1);
        BaseBet[] memory bets1a = new BaseBet[](1);
        bets1a[0] = BaseBet({amount: 5 ether, side: true});
        run_game_with_values(amount, bets1a, onkas);

        // Test 1B: Multiple One-Sided bets
        // uint256 bet_amount2 = 3 ether;
        // place_bet_and_verify_balances(game_id, cfg.ADDR_BETOOR_2, true, bet_amount2);
        // verify_bet_pool_state(game_id, bet_amount1 + bet_amount2,0, bet_amount1 + bet_amount2);
        BaseBet[] memory bets1b = new BaseBet[](2);
        bets1b[0] = BaseBet({amount: 3 ether, side: false});
        bets1b[1] = BaseBet({amount: 2 ether, side: false});
        run_game_with_values(amount + 1 gwei, bets1b, onkas);

        // Test 2A: Bet on opposite sides
        // uint256 bet_amount3 = 7 ether;
        // place_bet_and_verify_balances(game_id, cfg.ADDR_BETOOR_2, false, bet_amount3);
        // verify_bet_pool_state(game_id, bet_amount1 + bet_amount2 + bet_amount3,bet_amount3, bet_amount1 + bet_amount2);
        BaseBet[] memory bets2a = new BaseBet[](2);
        bets2a[0] = BaseBet({amount: 7 ether, side: false});
        bets2a[1] = BaseBet({amount: 7 ether, side: true});
        run_game_with_values(amount + 2 gwei, bets2a, onkas);

        // Test 2B: Multiple Bets on opposite sides
        BaseBet[] memory bets2b = new BaseBet[](4);
        bets2b[0] = BaseBet({amount: 7 ether, side: true});
        bets2b[1] = BaseBet({amount: 7 ether, side: false});
        bets2b[2] = BaseBet({amount: 11 gwei, side: false});
        bets2b[3] = BaseBet({amount: 11 gwei, side: true});
        run_game_with_values(amount + 3 gwei, bets2b, onkas);

        // Test 3A: Asymmetric Bet on opposite sides
        BaseBet[] memory bets3a = new BaseBet[](2);
        bets3a[0] = BaseBet({amount: 2 ether, side: true});
        bets3a[1] = BaseBet({amount: 7 ether, side: false});
        run_game_with_values(amount + 4 gwei, bets3a, onkas);

        // Test 3B: Multiple Asymmetric Bets on opposite sides
        BaseBet[] memory bets3b = new BaseBet[](5);
        bets3b[0] = BaseBet({amount: 2 ether, side: true});
        bets3b[1] = BaseBet({amount: 7 ether, side: false});
        bets3b[2] = BaseBet({amount: 11 gwei, side: false});
        bets3b[3] = BaseBet({amount: 13 gwei, side: true});
        bets3b[4] = BaseBet({amount: 1 ether, side: true});
        run_game_with_values(amount + 5 gwei, bets3b, onkas);

        // Test 4: Betting after game starts should fail

        // Record balances before game completion
        uint256 player1_balance_before = token.balanceOf(cfg.ADDR_PLAYER_1);
        uint256 player2_balance_before = token.balanceOf(cfg.ADDR_PLAYER_2);
        uint256 bettor1_balance_before = token.balanceOf(cfg.ADDR_BETOOR_1);
        uint256 bettor2_balance_before = token.balanceOf(cfg.ADDR_BETOOR_2);
        uint256 marketing_balance_before = token.balanceOf(cfg.ADDR_MARKETING);

        uint256 game_id = create_game_and_verify_balances([Player(cfg.ADDR_PLAYER_1, onka_p1), Player(cfg.ADDR_PLAYER_2, onka_p2)], amount);
        start_game_and_verify_balances(game_id);

        vm.startPrank(cfg.ADDR_OPERATOR);
        vm.expectRevert();
        game.place_bet(game_id, cfg.ADDR_BETOOR_1, true, 1 ether);
        vm.stopPrank();

        // Abort current game first
        abort_game(game_id);

        // Verify all participants received refunds
        Balance[] memory expected_bals = new Balance[](4);
        expected_bals[0] = Balance(cfg.ADDR_PLAYER_1, player1_balance_before);
        expected_bals[1] = Balance(cfg.ADDR_PLAYER_2, player2_balance_before);
        expected_bals[2] = Balance(cfg.ADDR_BETOOR_1, bettor1_balance_before);
        expected_bals[3] = Balance(cfg.ADDR_BETOOR_2, bettor2_balance_before);
        verify_balances(expected_bals);

        // reset expected balances
        player1_balance_before = token.balanceOf(cfg.ADDR_PLAYER_1);
        player2_balance_before = token.balanceOf(cfg.ADDR_PLAYER_2);
        bettor1_balance_before = token.balanceOf(cfg.ADDR_BETOOR_1);
        bettor2_balance_before = token.balanceOf(cfg.ADDR_BETOOR_2);
        marketing_balance_before = token.balanceOf(cfg.ADDR_MARKETING);

        // Test 5: Complete game flow with bets and verify payouts with MANUALLY verified calcs

        // bets
        Speculation[] memory speculations = new Speculation[](2);
        uint256 amt = 10 ether;
        uint256 bet1 = 5 ether;
        uint256 bet2 = 7 ether;
        uint256 rev = 64 gwei * 10 ** 7; // 0.64 ether (2% of 32 ether)
        speculations[0] = Speculation(cfg.ADDR_BETOOR_1, false, bet1); // Bet on P1
        speculations[1] = Speculation(cfg.ADDR_BETOOR_2, true, bet2); // Bet on P2

        // Create new game
        uint256 game_contract_balance_before = token.balanceOf(address(game));
        game_id = setup_game_with_bets([Player(cfg.ADDR_PLAYER_1, onka_p1), Player(cfg.ADDR_PLAYER_2, onka_p2)], amt, speculations);
        // Finish game
        complete_created_game_flow(game_id);

        // Verify balances after game completion
        GameData memory game_data = game.get_game(game_id);
        bool player1_won = game_data.p1_wins > game_data.p2_wins;

        // Calculate expected payouts using helper
        (uint256 marketing_share, uint256 p_win_share, uint256 bettor_share) = calculate_expected_payouts(game_id);

        if (player1_won) {
            assertEq(
                token.balanceOf(cfg.ADDR_PLAYER_1),
                player1_balance_before + ((amt * 2 - 40 gwei * 10 ** 7) - amt),
                "(Static value check) Player1 should receive winnings"
            );
            assertEq(token.balanceOf(cfg.ADDR_PLAYER_1), player1_balance_before - amount + p_win_share, "Player1 should receive winnings");
            assertEq(
                token.balanceOf(cfg.ADDR_BETOOR_1),
                bettor1_balance_before - bet1 + (1176 gwei * 10 ** 7),
                "(Static value check) Bettor1 should receive winnings"
            );
            assertEq(token.balanceOf(cfg.ADDR_BETOOR_1), bettor1_balance_before - bet1 + bettor_share, "Bettor1 should receive winnings");
        } else {
            assertEq(
                token.balanceOf(cfg.ADDR_PLAYER_2),
                player2_balance_before + ((amt * 2 - 40 gwei * 10 ** 7) - amt),
                "(Static value check) Player2 should receive winnings"
            );
            assertEq(token.balanceOf(cfg.ADDR_PLAYER_2), player2_balance_before - amount + p_win_share, "Player2 should receive winnings");
            assertEq(token.balanceOf(cfg.ADDR_BETOOR_2), bettor2_balance_before - bet2 + (1176 gwei * 10 ** 7), "Bettor2 should receive winnings");
            assertEq(token.balanceOf(cfg.ADDR_BETOOR_2), bettor2_balance_before - bet2 + bettor_share, "Bettor2 should receive winnings");
        }

        // Marketing should always receive its share
        assertEq(token.balanceOf(cfg.ADDR_MARKETING), marketing_balance_before + rev, "(Static value check) Marketing should receive fee");
        assertEq(token.balanceOf(cfg.ADDR_MARKETING), marketing_balance_before + marketing_share, "Marketing should receive fee");

        // contract balance should be the same as before the game
        uint256 epsilon = (5 wei * 2) + 1 wei;
        assertLt(token.balanceOf(address(game)), game_contract_balance_before + epsilon, "Contract balance should be the same (within epsilon)");
    }

    // Test revenue sharing
    function test_revenue_sharing() public {
        register_users();
        uint256 game_amt = 10 ether;
        uint256 bet_amt = 5 ether;

        uint256[] memory onkas = new uint256[](2);
        onkas[0] = onka_p1;
        onkas[1] = onka_p2;

        BaseBet[] memory bets = new BaseBet[](2);
        bets[0] = BaseBet({amount: bet_amt, side: false});
        bets[1] = BaseBet({amount: bet_amt, side: true});

        uint256 marketing_balance_before = token.balanceOf(cfg.ADDR_MARKETING);

        // Default revenue sharing (2%)
        run_game_with_values(game_amt, bets, onkas);

        assertEq(token.balanceOf(cfg.ADDR_MARKETING), marketing_balance_before + 6 gwei * 10 ** 8, "Marketing should receive fee");
    }

    function testfuzz_revenue_sharing(uint256 rev_share_bps) public {
        vm.assume(rev_share_bps <= 3000);

        register_users();
        uint256 game_amt = 10 ether;
        uint256 bet_amt = 5 ether;
        uint256 expected_revenue = FPML.fullMulDiv((game_amt * 2 + bet_amt * 2), rev_share_bps, 10_000);

        uint256[] memory onkas = new uint256[](2);
        onkas[0] = onka_p1;
        onkas[1] = onka_p2;

        BaseBet[] memory bets = new BaseBet[](2);
        bets[0] = BaseBet({amount: bet_amt, side: false});
        bets[1] = BaseBet({amount: bet_amt, side: true});

        uint256 marketing_balance_before = token.balanceOf(cfg.ADDR_MARKETING);

        vm.prank(cfg.ADDR_DEPLOYER);
        game.set_revenue(rev_share_bps);
        run_game_with_values(game_amt, bets, onkas);

        assertEq(token.balanceOf(cfg.ADDR_MARKETING), marketing_balance_before + expected_revenue, "Marketing should receive fee");
    }

    // Test randomness and game execution
    function testfuzz_game_randomness(uint8 randomness_sources) public {
        vm.assume(randomness_sources > 0 && randomness_sources <= 7);
        // set varying randomness providers & verify execution
        register_users();
        uint256 game_amt = 10 ether;
        uint256 bet_amt = 5 ether;

        uint256[] memory onkas = new uint256[](2);
        onkas[0] = onka_p1;
        onkas[1] = onka_p2;

        BaseBet[] memory bets = new BaseBet[](2);
        bets[0] = BaseBet({amount: bet_amt, side: false});
        bets[1] = BaseBet({amount: bet_amt, side: true});

        console.log("Randomness sources flags:");
        if (randomness_sources & 1 == 1) console.log("- Pyth enabled");
        if (randomness_sources & 2 == 2) console.log("- Randomizer enabled");
        if (randomness_sources & 4 == 4) console.log("- SAV enabled");

        // specify sources and run
        vm.prank(cfg.ADDR_DEPLOYER);
        wyrd.set_sources(randomness_sources);
        run_game_with_values(game_amt, bets, onkas);
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
