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

struct Balance {
    address addr;
    uint256 val;
}

contract OnkasOujiGameIntegrationTest is OnkasOujiGameTestHelpers {
    // Constants
    uint256 private constant GAME_AMOUNT = 100 * 10 ** 18;
    uint256 private constant BET_AMOUNT = 10 * 10 ** 18;
    uint256 ROLE_OPERATOR = 1 << 0;
    uint256 ROLE_SAV_PROVER = 1 << 1;

    // Contract instances
    TestableOnkasOujiGame private game;
    TestNFT private nft;
    TestERC20 private token;
    MockPythEntropy private pyth_entropy;
    MockRandomizer private randomizer;

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
        bytes32 random_value = bytes32(uint256(0x8888888888888888888888888888888888888888888888888888888888888888));
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

    function register_users(address[] memory players) public {
        for (uint256 i = 0; i < players.length; i++) {
            vm.startPrank(players[i]);
            token.approve(address(game), type(uint256).max);
            bytes32 secret = keccak256(abi.encodePacked("secret_", players[i]));
            vm.expectEmit(true, true, false, true, address(game));
            emit OnkasOujiGame.UserRegistered(secret, players[i]);
            game.register(secret);
            vm.stopPrank();
        }
    }

    function register_user(address player, bytes32 secret) internal {
        vm.startPrank(player);
        vm.deal(player, 0.1 ether);
        token.approve(address(game), type(uint256).max);
        vm.expectEmit(true, true, false, true, address(game));
        emit OnkasOujiGame.UserRegistered(secret, player);
        game.register(secret);
        vm.stopPrank();
    }

    /**
     * @notice Sets up a complete game with players and bets
     * @param players Two Player structs for the game participants
     * @param amount Stake amount per player
     * @param speculations Array of bets to place
     * @param register If true, registers all participants
     * @return game_id The created game's ID
     *
     * Checks: registrations, balances before/after game creation
     * and betting, game data validity, active games list inclusion
     */
    function setup_game(Player[2] memory players, uint256 amount, Speculation[] memory speculations, bool register)
        public
        returns (uint256 game_id)
    {
        // Register all users
        if (register) {
            address[] memory all_addresses = new address[](players.length + speculations.length);
            for (uint256 i = 0; i < players.length; i++) {
                all_addresses[i] = players[i].addr;
            }
            for (uint256 i = 0; i < speculations.length; i++) {
                all_addresses[players.length + i] = speculations[i].speculator;
            }
            register_users(all_addresses);
        }

        // initial balances
        uint256[2] memory player_initial_balances;
        uint256[] memory speculator_initial_balances = new uint256[](speculations.length);
        player_initial_balances[0] = token.balanceOf(players[0].addr);
        player_initial_balances[1] = token.balanceOf(players[1].addr);
        console.log("Initial balance for player 0:", player_initial_balances[0]);
        console.log("Initial balance for player 1:", player_initial_balances[1]);
        for (uint256 i = 0; i < speculations.length; i++) {
            speculator_initial_balances[i] = token.balanceOf(speculations[i].speculator);
            console.log("Initial balance for speculator", i, ":", speculator_initial_balances[i]);
        }

        // new game
        game_id = create_game(players, amount);

        // check game state: game data
        GameData memory game_data = game.get_game(game_id);
        assertEq(uint8(game_data.status), uint8(GameStatus.OPEN), "Game should be in OPEN status");
        assertEq(game_data.amount, amount, string.concat("Game amount should be ", vm.toString(amount)));
        assertEq(game_data.players[0].addr, players[0].addr, "Player 0 address incorrect");
        assertEq(game_data.players[0].nft_id, players[0].nft_id, "Player 0 NFT ID incorrect");
        assertEq(game_data.players[1].addr, players[1].addr, "Player 1 address incorrect");
        assertEq(game_data.players[1].nft_id, players[1].nft_id, "Player 1 NFT ID incorrect");
        assertEq(game_data.bet_pool, 0, "Bet pool should be empty initially");
        assertEq(game_data.p1_wins, 0, "Player 1 wins should be 0 initially");
        assertEq(game_data.p2_wins, 0, "Player 2 wins should be 0 initially");

        // check game state: active games list
        uint256[] memory active_game_ids = game.get_active_game_ids();
        bool game_found = false;
        for (uint256 i = 0; i < active_game_ids.length; i++) {
            if (active_game_ids[i] == game_id) {
                game_found = true;
                break;
            }
        }
        assertTrue(game_found, "Game should be in active games list");

        // check game state: player balances
        Balance[] memory balances = new Balance[](2);
        for (uint256 i = 0; i < 2; i++) {
            balances[i] = Balance(players[i].addr, player_initial_balances[i] - amount);
        }
        verify_balances(balances);

        // bets
        vm.startPrank(cfg.ADDR_OPERATOR);
        for (uint256 i = 0; i < speculations.length; i++) {
            game.place_bet(game_id, speculations[i].speculator, speculations[i].prediction, speculations[i].amount);
            // Check speculator balance after betting
            uint256 current_balance = token.balanceOf(speculations[i].speculator);
            console.log("Speculator", i, "balance after betting:", current_balance);
            assertEq(current_balance, speculator_initial_balances[i] - speculations[i].amount, "Speculator balance not reduced correctly");
        }
        vm.stopPrank();

        return game_id;
    }

    function create_game(Player[2] memory players, uint256 amount) internal returns (uint256) {
        return create_game(players, amount, 1);
    }

    function create_game(Player[2] memory players, uint256 amount, uint256 expected_id) internal returns (uint256) {
        return create_game(players, amount, expected_id, bytes32(uint256(0x1337)));
    }

    function create_game(Player[2] memory players, uint256 amount, uint256 expected_id, bytes32 alpha_prefix) internal returns (uint256) {
        vm.startPrank(cfg.ADDR_OPERATOR);
        vm.expectEmit(true, true, false, true, address(game));
        emit OnkasOujiGame.GameCreated(expected_id, players, amount);
        uint256 game_id = game.new_game(players, amount, alpha_prefix);
        vm.stopPrank();
        return game_id;
    }

    function verify_balances(Balance[] memory balances) internal view {
        for (uint256 i = 0; i < balances.length; i++) {
            Balance memory balance = balances[i];
            assertEq(token.balanceOf(balance.addr), balance.val, string.concat("Balance incorrect for ", vm.toString(balance.addr)));
        }
    }

    function verify_game_status(uint256 game_id, GameStatus expected_status) internal view {
        GameData memory game_data = game.get_game(game_id);
        assertEq(uint8(game_data.status), uint8(expected_status), string.concat("Game status should be ", string(abi.encode(expected_status))));
    }

    function set_user_token_balance(address user, uint256 new_balance) internal {
        vm.startPrank(user);
        uint256 current_balance = token.balanceOf(user);
        if (new_balance < current_balance) {
            token.transfer(address(0x1), current_balance - new_balance);
        } else if (new_balance > current_balance) {
            token.mint(user, new_balance - current_balance);
        }
        vm.stopPrank();
    }

    function abort_game(uint256 game_id) internal {
        vm.expectEmit(true, false, false, false, address(game));
        emit OnkasOujiGame.GameAborted(game_id);
        vm.prank(cfg.ADDR_OPERATOR);
        game.abort_game(game_id);

        // verify game status is now CANCELLED
        verify_game_status(game_id, GameStatus.CANCELLED);
    }

    function exec_game(uint256 game_id) internal {
        GameData memory game_data = game.get_game(game_id);
        OnkaStats memory o1_stats_before = game.get_onka_stats(game_data.players[0].nft_id);
        OnkaStats memory o2_stats_before = game.get_onka_stats(game_data.players[1].nft_id);

        verify_game_status(game_id, GameStatus.ACTIVE);

        vm.expectEmit(true, false, false, false, address(game));
        emit OnkasOujiGame.GameExecuted(game_id);
        vm.prank(cfg.ADDR_OPERATOR);
        game.exec_game(game_id);

        game_data = game.get_game(game_id);
        verify_game_status(game_id, GameStatus.UNSETTLED);

        // verify onka stats are updated
        OnkaStats memory o1_stats_after = game.get_onka_stats(game_data.players[0].nft_id);
        OnkaStats memory o2_stats_after = game.get_onka_stats(game_data.players[1].nft_id);

        assertEq(o1_stats_after.plays, o1_stats_before.plays + 1, "Onka 1 NFT plays should be incremented by 1");
        assertEq(o2_stats_after.plays, o2_stats_before.plays + 1, "Onka 2 NFT plays should be incremented by 1");

        if (game_data.p1_wins > game_data.p2_wins) {
            assertEq(o1_stats_after.wins, o1_stats_before.wins + 1, "Onka 1 NFT wins should be incremented by 1");
            assertEq(o2_stats_after.losses, o2_stats_before.losses + 1, "Onka 2 NFT losses should be incremented by 1");
        } else {
            assertEq(o2_stats_after.wins, o2_stats_before.wins + 1, "Onka 2 NFT wins should be incremented by 1");
            assertEq(o1_stats_after.losses, o1_stats_before.losses + 1, "Onka 1 NFT losses should be incremented by 1");
        }
    }

    function create_game_and_verify_balances(Player[2] memory players, uint256 amount, uint256 expected_id) internal returns (uint256) {
        return create_game_and_verify_balances(players, amount, expected_id, bytes32(uint256(0x1337)));
    }

    function create_game_and_verify_balances(Player[2] memory players, uint256 amount, uint256 expected_id, bytes32 alpha_prefix)
        internal
        returns (uint256)
    {
        Balance[] memory expected_bals = new Balance[](3);
        expected_bals[0] = Balance(players[0].addr, token.balanceOf(players[0].addr) - amount);
        expected_bals[1] = Balance(players[1].addr, token.balanceOf(players[1].addr) - amount);
        expected_bals[2] = Balance(address(game), token.balanceOf(address(game)) + amount * 2);

        uint256 game_id = create_game(players, amount, expected_id, alpha_prefix);
        verify_balances(expected_bals);
        verify_game_status(game_id, GameStatus.OPEN);

        return game_id;
    }

    function place_bet_and_verify_balances(uint256 game_id, address bettor, bool prediction, uint256 amount) internal {
        uint256 bettor_balance_before = token.balanceOf(bettor);
        uint256 contract_balance_before = token.balanceOf(address(game));
        Balance[] memory balances = new Balance[](2);

        vm.expectEmit(true, true, true, true, address(game));
        emit OnkasOujiGame.BetPlaced(game_id, bettor, prediction, amount);
        vm.prank(cfg.ADDR_OPERATOR);
        game.place_bet(game_id, bettor, prediction, amount);

        balances[0] = Balance(bettor, bettor_balance_before - amount);
        balances[1] = Balance(address(game), contract_balance_before + amount);
        verify_balances(balances);

        // Verify bet pool and game status
        GameData memory game_data = game.get_game(game_id);
        assertEq(game_data.bet_pool, contract_balance_before + amount - contract_balance_before, "Bet pool should contain bettor's funds"); // lol
        assertEq(uint8(game_data.status), uint8(GameStatus.OPEN), "Game should be in OPEN status");
    }

    function start_game_and_verify_balances(uint256 game_id) internal {
        Balance[] memory balances = new Balance[](2);
        balances[0] = Balance(cfg.ADDR_PLAYER_1, token.balanceOf(cfg.ADDR_PLAYER_1));
        balances[1] = Balance(cfg.ADDR_PLAYER_2, token.balanceOf(cfg.ADDR_PLAYER_2));

        verify_game_status(game_id, GameStatus.OPEN);
        (uint256 request_fee,,) = game.calc_fee();

        // Check for RandomnessRequested events for each activated provider
        uint8 active_sources = game.get_active_sources();
        console.log("Active sources:", active_sources);
        if (active_sources & cfg.FLAG_PYTH != 0) {
            vm.expectEmit(true, true, true, true, address(game));
            emit Wyrd.RandomnessRequested(game_id, cfg.FLAG_PYTH);
        }
        if (active_sources & cfg.FLAG_RANDOMIZER != 0) {
            vm.expectEmit(true, true, true, true, address(game));
            emit Wyrd.RandomnessRequested(game_id, cfg.FLAG_RANDOMIZER);
        }
        if (active_sources & cfg.FLAG_SAV != 0) {
            vm.expectEmit(true, true, true, true, address(game));
            emit Wyrd.RandomnessRequested(game_id, cfg.FLAG_SAV);
        }

        vm.prank(cfg.ADDR_OPERATOR);
        vm.expectEmit(true, false, false, false, address(game));
        emit OnkasOujiGame.GameStarted(game_id);
        game.start_game{value: request_fee}(game_id);
        // vm.stopPrank();
        verify_game_status(game_id, GameStatus.ACTIVE);

        // verify balances are unchanged
        verify_balances(balances);
    }

    function verify_game_not_active(uint256 game_id) internal view {
        uint256[] memory active_game_ids = game.get_active_game_ids();
        bool game_still_active = false;
        for (uint256 i = 0; i < active_game_ids.length; i++) {
            if (active_game_ids[i] == game_id) {
                game_still_active = true;
                break;
            }
        }
        assertFalse(game_still_active, "Game should be removed from active games list");
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
        // Create game
        // Place various bets
        // Verify odds calculation works correctly
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
