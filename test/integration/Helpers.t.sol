// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {Wyrd} from "src/Wyrd.sol";
import {OnkasOujiGame} from "src/OnkasOujiGame.sol";
import {OwnableRoles} from "solady/auth/OwnableRoles.sol";
import "test/config.sol" as cfg;
import {VRFTestData} from "test/utils/VRFTestData.sol";
import {MockPythEntropy, MockRandomizer} from "test/mocks/MockRandomProviders.t.sol";
import {IEntropy} from "@pythnetwork/entropy-sdk-solidity/IEntropy.sol";
import {IRandomizer} from "src/interfaces/ext/IRandomizer.sol";
import {IWyrd} from "src/interfaces/IWyrd.sol";
import {MockPythEntropy, MockRandomizer} from "test/mocks/MockRandomProviders.t.sol";
import {TestNFT} from "test/mocks/MockERC721.t.sol";
import {TestERC20} from "test/mocks/MockERC20.t.sol";
import {GameData, GameStatus, Player, Speculation, RoundResult, OnkaStats} from "src/lib/models.sol";

interface ITestableWyrd is IWyrd {
    function vrf_tester() external returns (VRFTestData);

    function request_random(uint256 req_id, bytes32 alpha) external payable;

    // Expose internal variables for testing
    function get_role_operator() external pure returns (uint256);

    function get_role_sav_prover() external pure returns (uint256);

    function get_store_alpha_inputs() external view returns (bool);

    function pyth_cbidx_req(uint64 seq_num) external view returns (uint256);
}

contract TestableWyrd is Wyrd, ITestableWyrd {
    VRFTestData internal _vrf_tester;

    constructor(uint8 _flags, address _pyth_entropy, address _pyth_provider, address _randomizer, uint256[2] memory _sav_pk, bool _store_alpha)
        Wyrd(_flags, _pyth_entropy, _pyth_provider, _randomizer, _sav_pk, _store_alpha)
    {
        _vrf_tester = new VRFTestData();
    }

    function vrf_tester() public returns (VRFTestData) {
        return _vrf_tester;
    }

    function request_random(uint256 req_id, bytes32 alpha) external payable {
        _request_random(req_id, alpha);
    }

    // Expose internal variables for testing
    function get_role_operator() external pure returns (uint256) {
        return ROLE_OPERATOR;
    }

    function get_role_sav_prover() external pure returns (uint256) {
        return ROLE_SAV_PROVER;
    }

    function get_store_alpha_inputs() external view returns (bool) {
        return STORE_ALPHA_INPUTS;
    }

    function pyth_cbidx_req(uint64 seq_num) external view returns (uint256) {
        return _pyth_cbidx_req[seq_num];
    }
}

contract TestableOnkasOujiGame is ITestableWyrd, OnkasOujiGame {
    VRFTestData internal _vrf_tester;

    constructor(
        address _nft_contract,
        address _token_contract,
        address _pyth_entropy,
        address _pyth_provider,
        address _randomizer,
        uint256[2] memory _sav_pk,
        address _marketing_wallet
    ) OnkasOujiGame(_nft_contract, _token_contract, _pyth_entropy, _pyth_provider, _randomizer, _sav_pk, _marketing_wallet) {
        _vrf_tester = new VRFTestData();
    }

    function vrf_tester() public returns (VRFTestData) {
        return _vrf_tester;
    }

    function request_random(uint256 req_id, bytes32 alpha) external payable {
        _request_random(req_id, alpha);
    }

    // Expose internal variables for testing
    function get_role_operator() external pure returns (uint256) {
        return ROLE_OPERATOR;
    }

    function get_role_sav_prover() external pure returns (uint256) {
        return ROLE_SAV_PROVER;
    }

    function get_store_alpha_inputs() external view returns (bool) {
        return STORE_ALPHA_INPUTS;
    }

    function pyth_cbidx_req(uint64 seq_num) external view returns (uint256) {
        return _pyth_cbidx_req[seq_num];
    }
}

interface IMockEntropy is IEntropy {
    function triggerCallback(uint64 sequenceNumber) external;

    function getLatestSequenceNumber(address provider) external view returns (uint64);
}

abstract contract WyrdTestHelpers is Test {
    uint8 public constant FLAG_PYTH = cfg.FLAG_PYTH;
    uint8 public constant FLAG_RANDOMIZER = cfg.FLAG_RANDOMIZER;
    uint8 public constant FLAG_SAV = cfg.FLAG_SAV;
    Wyrd wyrd;
    ITestableWyrd twyrd;

    // Mock providers
    MockPythEntropy mock_pyth_entropy;
    MockRandomizer mock_randomizer;

    function grant_roles(address user, uint256 roles) internal {
        grant_roles(address(wyrd), user, roles);
    }

    function grant_roles(address ca, address user, uint256 roles) public {
        uint256 new_roles = OwnableRoles(ca).rolesOf(user) | roles;
        vm.startPrank(cfg.ADDR_DEPLOYER);
        vm.expectEmit(true, true, false, true, ca);
        emit OwnableRoles.RolesUpdated(user, new_roles);
        OwnableRoles(ca).grantRoles(user, roles);
        vm.stopPrank();
    }

    function revoke_roles(address user, uint256 roles) internal {
        revoke_roles(address(wyrd), user, roles);
    }

    function revoke_roles(address ca, address user, uint256 roles) public {
        uint256 new_roles = OwnableRoles(ca).rolesOf(user) & ~roles;
        console.log("Old roles for user:", OwnableRoles(ca).rolesOf(user));
        console.log("Revoking roles:", roles);
        console.log("Expected new roles:", new_roles);
        vm.startPrank(cfg.ADDR_DEPLOYER);
        vm.expectEmit(true, true, false, true, ca);
        emit OwnableRoles.RolesUpdated(user, new_roles);
        OwnableRoles(ca).revokeRoles(user, roles);
        vm.stopPrank();
    }

    function make_request(uint256 req_id, bytes32 alpha) internal {
        (uint256 required_fee,,) = wyrd.calc_fee();
        vm.deal(cfg.ADDR_OPERATOR, required_fee);

        uint8 active_sources = wyrd.get_active_sources();
        console.log("Active sources:", active_sources);
        if (active_sources & cfg.FLAG_PYTH != 0) {
            vm.expectEmit(true, true, true, true, address(wyrd));
            emit Wyrd.RandomnessRequested(req_id, cfg.FLAG_PYTH);
        }
        if (active_sources & cfg.FLAG_RANDOMIZER != 0) {
            vm.expectEmit(true, true, true, true, address(wyrd));
            emit Wyrd.RandomnessRequested(req_id, cfg.FLAG_RANDOMIZER);
        }
        if (active_sources & cfg.FLAG_SAV != 0) {
            vm.expectEmit(true, true, true, true, address(wyrd));
            emit Wyrd.RandomnessRequested(req_id, cfg.FLAG_SAV);
        }

        vm.prank(cfg.ADDR_OPERATOR);
        twyrd.request_random{value: required_fee}(req_id, alpha);
    }

    // 3 params
    function verify_request_status(uint256 req_id, bool req_active, uint8 expected_sources) internal view returns (uint8 active_sources) {
        active_sources = verify_request_status(req_id, req_active, expected_sources, false, 0);
    }

    // 4 params
    function verify_request_status(uint256 req_id, bool req_active, bool flag_enabled, uint8 flag) internal view returns (uint8 active_sources) {
        bool active;
        (active, active_sources) = wyrd.get_request_status(req_id);
        active_sources = verify_request_status(req_id, req_active, active_sources, flag_enabled, flag);
    }

    // 5 params
    function verify_request_status(uint256 req_id, bool req_active, uint8 expected_sources, bool flag_enabled, uint8 flag)
        internal
        view
        returns (uint8 active_sources)
    {
        bool active;
        (active, active_sources) = wyrd.get_request_status(req_id);
        assertEq(active, req_active, "Request active status mismatch");
        assertEq(active_sources, expected_sources, "Remaining sources mismatch");
        assertTrue((active_sources & flag != 0) == flag_enabled, "Flag mismatch");
        // return active_sources;
    }

    function verify_random_value(uint256 req_id, bool expected_completed) internal view {
        (bytes32 rand, bool completed) = wyrd.get_random_value(req_id);
        assertEq(completed, expected_completed, "Random value completion status mismatch");
        assertNotEq(rand, bytes32(0), "Random value should not be zero");
    }

    // Helper function to verify SAV VRF data
    function dry_verify_sav_vrf_data(
        uint256[2] memory pk,
        bytes memory pub,
        bytes memory pi,
        uint256[4] memory proof,
        bytes memory alpha,
        bytes32 beta,
        uint256[2] memory U,
        uint256[4] memory V
    ) internal {
        uint256[2] memory decoded_pk = twyrd.vrf_tester().decodePoint(pub);
        assertEq(decoded_pk[0], pk[0]);
        assertEq(decoded_pk[1], pk[1]);

        uint256[4] memory decoded_proof = twyrd.vrf_tester().decodeProof(pi);
        assertEq(decoded_proof[0], proof[0]);
        assertEq(decoded_proof[1], proof[1]);
        assertEq(decoded_proof[2], proof[2]);
        assertEq(decoded_proof[3], proof[3]);

        bool local_verify = twyrd.vrf_tester().verify(pk, proof, alpha);
        assertTrue(local_verify, "Local proof verification failed");

        (uint256[2] memory _U, uint256[4] memory _V) = wyrd.compute_fast_verify_params(proof, alpha);
        console.log("Passed U values:");
        console.log(U[0], U[1]);
        console.log("Passed V values:");
        console.log(V[0], V[1], V[2], V[3]);
        console.log("Computed U values:");
        console.log(_U[0], _U[1]);
        console.log("Computed V values:");
        console.log(_V[0], _V[1], _V[2], _V[3]);
        assertTrue(U[0] == _U[0] && U[1] == _U[1], "U values should match");
        assertTrue(V[0] == _V[0] && V[1] == _V[1] && V[2] == _V[2] && V[3] == _V[3], "V values should match");
    }

    function trigger_pyth_callback() internal {
        address ca = address(mock_pyth_entropy);
        uint64 idx = IMockEntropy(ca).getLatestSequenceNumber(cfg.ADDR_PYTH_PROVIDER);
        trigger_pyth_callback(idx, ca);
    }

    function trigger_pyth_callback(uint64 sequence_num) internal {
        trigger_pyth_callback(sequence_num, address(mock_pyth_entropy));
    }

    function trigger_pyth_callback(uint64 sequence_num, address mock_pyth) public {
        // Check request status has pyth enabled
        uint256 req_id = twyrd.pyth_cbidx_req(sequence_num);
        verify_request_status(req_id, true, true, FLAG_PYTH);

        // Check for RandomnessGenerated event
        vm.expectEmit(true, true, false, true, address(wyrd));
        emit Wyrd.RandomnessGenerated(req_id, FLAG_PYTH);
        vm.prank(cfg.ADDR_PYTH_PROVIDER);
        IMockEntropy(mock_pyth).triggerCallback(sequence_num);
    }

    function trigger_randomizer_callback() internal {
        uint256 idx = uint256(keccak256(abi.encodePacked(block.timestamp, address(wyrd))));
        trigger_randomizer_callback(idx);
    }

    function trigger_randomizer_callback(uint256 idx) internal {
        trigger_randomizer_callback(idx, address(mock_randomizer));
    }

    function trigger_randomizer_callback(uint256 randomizer_req_id, address prank_addr) internal {
        bytes32 randomizer_result = keccak256(abi.encodePacked("randomizer", randomizer_req_id));
        vm.prank(prank_addr);
        wyrd.randomizerCallback(randomizer_req_id, randomizer_result);
    }

    function trigger_randomizer_callback(uint256 randomizer_req_id, address prank_addr, address wyrd_addr) public {
        bytes32 randomizer_result = keccak256(abi.encodePacked("randomizer", randomizer_req_id));
        vm.prank(prank_addr);
        Wyrd(wyrd_addr).randomizerCallback(randomizer_req_id, randomizer_result);
    }

    function sav_update_public_key() public {
        uint256[2] memory pk = twyrd.vrf_tester().get_pk();
        vm.warp(block.timestamp + 5 hours);
        vm.prank(cfg.ADDR_SAV_PROVER);
        wyrd.set_sav_public_key(pk);
    }

    function trigger_sav_callback(uint256 req_id) internal {
        // sav triggers,
        // first, lookup alpha value
        // prove it -> get hash, pi
        // submit
        bytes32 alpha = wyrd.get_alpha(req_id);
        (uint256[2] memory pk, uint256[4] memory proof, uint256[2] memory U, uint256[4] memory V, bytes32 beta, bytes memory pi, bytes memory pub) =
            twyrd.vrf_tester().generate_vrf_proof(alpha);

        dry_verify_sav_vrf_data(pk, pub, pi, proof, bytes.concat(alpha), beta, U, V);

        // Check req_executions value before callback
        uint8 remaining_sources_before = verify_request_status(req_id, true, true, FLAG_SAV);

        // Compute the expected remaining sources after the callback
        uint8 expected_remaining_sources_after = remaining_sources_before ^ FLAG_SAV;

        vm.startPrank(cfg.ADDR_SAV_PROVER);
        vm.expectEmit(true, true, false, true, address(wyrd));
        emit Wyrd.RandomnessGenerated(req_id, FLAG_SAV);
        if (expected_remaining_sources_after == 0) {
            vm.expectEmit(true, true, false, true, address(wyrd));
            emit Wyrd.RequestCompleted(req_id);
        }
        wyrd.sav_callback(req_id, bytes.concat(alpha), beta, proof, U, V);
        vm.stopPrank();

        // Check req_executions value after callback
        verify_request_status(req_id, expected_remaining_sources_after != 0, expected_remaining_sources_after, false, FLAG_SAV);
    }

    function ext_process_request_callbacks(uint256 req_id) internal {
        // wyrd = Wyrd(_wyrd);
        uint8 sources = twyrd.get_active_sources();
        verify_request_status(req_id, true, sources);
        console.log("Processing sources:", sources);
        if (sources & cfg.FLAG_PYTH != 0) {
            trigger_pyth_callback();
        }
        if (sources & cfg.FLAG_RANDOMIZER != 0) {
            trigger_randomizer_callback();
        }
        if (sources & cfg.FLAG_SAV != 0) {
            trigger_sav_callback(req_id);
        }
    }
}

abstract contract OnkasOujiGameTestHelpers is WyrdTestHelpers {
    struct Balance {
        address addr;
        uint256 val;
    }

    // Constants
    uint256 internal constant GAME_AMOUNT = 100 * 10 ** 18;
    uint256 internal constant BET_AMOUNT = 10 * 10 ** 18;
    uint256 ROLE_OPERATOR = 1 << 0;
    uint256 ROLE_SAV_PROVER = 1 << 1;

    // Contract instances
    TestableOnkasOujiGame internal game;
    TestNFT internal nft;
    TestERC20 internal token;
    MockPythEntropy internal pyth_entropy;
    MockRandomizer internal randomizer;

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
        uint256 bet_pool_before = game.get_game(game_id).bet_pool;
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
        assertEq(game_data.bet_pool, bet_pool_before + amount, "Bet pool should contain bettor's funds"); // lol
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

        // start game
        vm.prank(cfg.ADDR_OPERATOR);
        vm.expectEmit(true, false, false, false, address(game));
        emit OnkasOujiGame.GameStarted(game_id);
        game.start_game{value: request_fee}(game_id);
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

    function create_game(Player[2] memory players, uint256 amount) internal returns (uint256) {
        return create_game(players, amount, game.get_current_game_id()+1);
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

    function verify_bet_pool_state(uint256 game_id, uint256 expected_pool, uint256 expected_p1_bets, uint256 expected_p2_bets) internal view {
        GameData memory game_data = game.get_game(game_id);
        assertEq(game_data.bet_pool, expected_pool, "Bet pool amount mismatch");

        // Calculate actual bets on each side
        (,, uint256 p1_depth, uint256 p2_depth) = game.calc_book(game_id);
        assertEq(p1_depth, expected_p1_bets, "Player1 bets total mismatch");
        assertEq(p2_depth, expected_p2_bets, "Player2 bets total mismatch");
    }

    function calculate_expected_payouts(uint256 game_id)
        internal
        view
        returns (
            uint256 marketing_share,
            uint256 p_win_share,
            uint256 bettor_p1_share,
            uint256 bettor_p2_share
        )
    {
        GameData memory game_data = game.get_game(game_id);
        uint256 total_pool = game_data.amount * 2 + game_data.bet_pool;
        uint marketing_share_bets = game_data.bet_pool * game.get_revenue_bps() / 10_000;
        uint marketing_share_game = (game_data.amount*2) * game.get_revenue_bps() / 10_000;
        marketing_share = marketing_share_bets + marketing_share_game;

        (uint256 p1_odds, uint256 p2_odds, uint256 p1_depth, uint256 p2_depth) = game.calc_book(game_id);

        p_win_share = game_data.amount * 2;

        if (p1_depth > 0 && p2_depth > 0) {
            // Both sides have bets
            uint256 marketing_share_p1 = p1_depth * game.get_revenue_bps() / 10_000;
            uint256 marketing_share_p2 = p2_depth * game.get_revenue_bps() / 10_000;
            bettor_p1_share = p1_depth - marketing_share_p1;
            bettor_p2_share = p2_depth - marketing_share_p2;
        } else {
            // One-sided betting pool

        }
    }

    function complete_created_game_flow(uint256 game_id) internal {
        // Start game
        start_game_and_verify_balances(game_id);

        // Process callbacks
        ext_process_request_callbacks(game_id);

        // Execute game
        exec_game(game_id);

        // End game
        vm.prank(cfg.ADDR_OPERATOR);
        game.end_game(game_id);
    }

    function setup_game_with_bets(Player[2] memory players, uint256 amount, Speculation[] memory speculations) internal returns (uint256 game_id) {
        // Register users
        address[] memory all_addresses = new address[](players.length + speculations.length);
        for (uint256 i = 0; i < players.length; i++) {
            all_addresses[i] = players[i].addr;
        }
        for (uint256 i = 0; i < speculations.length; i++) {
            all_addresses[players.length + i] = speculations[i].speculator;
        }
        register_users(all_addresses);

        // Create game
        game_id = create_game(players, amount);

        // Place bets
        vm.startPrank(cfg.ADDR_OPERATOR);
        for (uint256 i = 0; i < speculations.length; i++) {
            game.place_bet(game_id, speculations[i].speculator, speculations[i].prediction, speculations[i].amount);
        }
        vm.stopPrank();

        return game_id;
    }
}
