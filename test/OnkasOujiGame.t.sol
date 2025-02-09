// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/OnkasOujiGame.sol";
import "../src/lib/models.sol";
import {MockERC721} from "./mocks/MockERC721.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockEntropy} from "./mocks/MockEntropy.sol";

contract OnkasOujiGameTest is Test {
    // Constants
    uint256 constant INITIAL_BALANCE = 1000 ether;
    uint256 constant GAME_AMOUNT = 1 ether;
    uint256 constant ENTROPY_FEE = 0.1 ether;

    // Test addresses
    address constant PLAYER_ONE = address(0x1);
    address constant PLAYER_TWO = address(0x2);
    address constant SPECULATOR_ONE = address(0x3);
    address constant SPECULATOR_TWO = address(0x4);
    address constant OPERATOR = address(0x5);
    address constant MARKETING = address(0x6);
    address constant PROVIDER = address(0x7);

    // Contract instances
    OnkasOujiGame private game;
    MockERC721 private nft;
    MockERC20 private token;
    MockEntropy private entropy;

    // Setup function run before each test
    function setUp() public {
        // Deploy mock contracts
        nft = new MockERC721();
        token = new MockERC20();
        entropy = new MockEntropy();

        // Deploy main contract
        game = new OnkasOujiGame(address(nft), address(token), address(entropy), PROVIDER, MARKETING);

        // Setup roles
        game.grantRoles(OPERATOR, game.ROLE_OPERATOR());

        // Setup initial states
        vm.deal(OPERATOR, INITIAL_BALANCE);

        // Mint NFTs and tokens
        _setup_player(PLAYER_ONE, 1);
        _setup_player(PLAYER_TWO, 2);
        _setup_speculator(SPECULATOR_ONE);
        _setup_speculator(SPECULATOR_TWO);
    }

    function _setup_player(address player, uint256 nft_id) internal {
        // Mint NFT
        nft.mint(player, nft_id);

        // Mint and approve tokens
        token.mint(player, INITIAL_BALANCE);
        vm.prank(player);
        token.approve(address(game), type(uint256).max);
    }

    function _setup_speculator(address speculator) internal {
        token.mint(speculator, INITIAL_BALANCE);
        vm.prank(speculator);
        token.approve(address(game), type(uint256).max);
    }

    // Test Game Creation
    function test_new_game() public {
        Player[2] memory players = [Player(PLAYER_ONE, 1), Player(PLAYER_TWO, 2)];

        vm.prank(OPERATOR);
        uint256 game_id = game.new_game(players, GAME_AMOUNT);

        assertEq(game_id, 1);

        GameData memory game_data = game.get_game(game_id);
        assertEq(uint8(game_data.status), uint8(GameStatus.OPEN));
        assertEq(game_data.amount, GAME_AMOUNT);
        assertEq(game_data.players[0].addr, PLAYER_ONE);
        assertEq(game_data.players[1].addr, PLAYER_TWO);
    }

    function test_new_game_revert_invalid_nft_ownership() public {
        Player[2] memory players = [
            Player(PLAYER_ONE, 2), // Player one doesn't own NFT 2
            Player(PLAYER_TWO, 1)
        ];

        vm.prank(OPERATOR);
        vm.expectRevert(abi.encodeWithSelector(OnkasOujiGame.InvalidNFTOwnership.selector, PLAYER_ONE, 2));
        game.new_game(players, GAME_AMOUNT);
    }

    // Test Betting
    function test_place_bet() public {
        // Create game first
        Player[2] memory players = [Player(PLAYER_ONE, 1), Player(PLAYER_TWO, 2)];
        vm.prank(OPERATOR);
        uint256 game_id = game.new_game(players, GAME_AMOUNT);

        // Place bet
        uint256 bet_amount = 0.5 ether;
        vm.prank(OPERATOR);
        game.place_bet(game_id, SPECULATOR_ONE, 0, bet_amount);

        GameData memory game_data = game.get_game(game_id);
        assertEq(game_data.totalbet, bet_amount);
        assertEq(game_data.speculations.length, 1);
        assertEq(game_data.speculations[0].speculator, SPECULATOR_ONE);
        assertEq(game_data.speculations[0].amount, bet_amount);
    }

    // Test Game Flow
    function test_complete_game_flow() public {
        // 1. Create game
        Player[2] memory players = [Player(PLAYER_ONE, 1), Player(PLAYER_TWO, 2)];
        vm.prank(OPERATOR);
        uint256 game_id = game.new_game(players, GAME_AMOUNT);

        // 2. Place bets
        vm.prank(OPERATOR);
        game.place_bet(game_id, SPECULATOR_ONE, 0, 0.5 ether);
        vm.prank(OPERATOR);
        game.place_bet(game_id, SPECULATOR_TWO, 1, 0.5 ether);

        // 3. Start game
        vm.prank(OPERATOR);
        game.start_game{value: ENTROPY_FEE}(game_id);

        // 4. Simulate entropy callback
        entropy.triggerCallback(1, PROVIDER, bytes32(uint256(1234567890)));

        // 5. End game
        vm.prank(OPERATOR);
        game.end_game(game_id);

        GameData memory game_data = game.get_game(game_id);
        assertEq(uint8(game_data.status), uint8(GameStatus.COMPLETED));
    }

    // Test Game Abortion
    function test_abort_game() public {
        // Create game
        Player[2] memory players = [Player(PLAYER_ONE, 1), Player(PLAYER_TWO, 2)];
        vm.prank(OPERATOR);
        uint256 game_id = game.new_game(players, GAME_AMOUNT);

        // Place bet
        vm.prank(OPERATOR);
        game.place_bet(game_id, SPECULATOR_ONE, 0, 0.5 ether);

        // Record balances before abort
        uint256 player_one_balance_before = token.balanceOf(PLAYER_ONE);
        uint256 player_two_balance_before = token.balanceOf(PLAYER_TWO);
        uint256 speculator_balance_before = token.balanceOf(SPECULATOR_ONE);

        // Abort game
        vm.prank(OPERATOR);
        game.abort_game(game_id);

        // Verify refunds
        assertEq(token.balanceOf(PLAYER_ONE), player_one_balance_before + GAME_AMOUNT);
        assertEq(token.balanceOf(PLAYER_TWO), player_two_balance_before + GAME_AMOUNT);
        assertEq(token.balanceOf(SPECULATOR_ONE), speculator_balance_before + 0.5 ether);

        GameData memory game_data = game.get_game(game_id);
        assertEq(uint8(game_data.status), uint8(GameStatus.CANCELLED));
    }

    // Test Revenue Sharing
    function test_revenue_sharing() public {
        // Create and complete a game with bets
        Player[2] memory players = [Player(PLAYER_ONE, 1), Player(PLAYER_TWO, 2)];

        vm.prank(OPERATOR);
        uint256 game_id = game.new_game(players, GAME_AMOUNT);

        vm.prank(OPERATOR);
        game.place_bet(game_id, SPECULATOR_ONE, 0, 1 ether);

        uint256 marketing_balance_before = token.balanceOf(MARKETING);

        vm.prank(OPERATOR);
        game.start_game{value: ENTROPY_FEE}(game_id);

        entropy.triggerCallback(1, PROVIDER, bytes32(uint256(1234567890)));

        vm.prank(OPERATOR);
        game.end_game(game_id);

        // Verify revenue share (2% of total pool)
        uint256 expected_revenue = (GAME_AMOUNT * 2 + 1 ether) * 200 / 10000; // 2% of total pool
        assertEq(token.balanceOf(MARKETING) - marketing_balance_before, expected_revenue);
    }

    // Fuzz Tests
    function testFuzz_place_bet(uint256 amount) public {
        // Bound amount to reasonable values
        amount = bound(amount, 0.0001 ether, 100 ether);

        Player[2] memory players = [Player(PLAYER_ONE, 1), Player(PLAYER_TWO, 2)];

        vm.prank(OPERATOR);
        uint256 game_id = game.new_game(players, GAME_AMOUNT);

        token.mint(SPECULATOR_ONE, amount);

        vm.prank(OPERATOR);
        game.place_bet(game_id, SPECULATOR_ONE, 0, amount);

        GameData memory game_data = game.get_game(game_id);
        assertEq(game_data.totalbet, amount);
    }
}
