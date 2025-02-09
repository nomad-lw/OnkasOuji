// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.26;

// Core imports
import {OwnableRoles} from "solady/auth/OwnableRoles.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// Interface imports
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Library imports
import {FixedPointMathLib as FPML} from "solady/utils/FixedPointMathLib.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

// Local imports
import {GameData, GameStatus, Player, Speculation, RoundResult, OnkaStats} from "./lib/models.sol";

contract OnkasOujiGame is ReentrancyGuard, OwnableRoles {
    using EnumerableSet for EnumerableSet.UintSet;

    // Constants
    uint256 public constant BATTLE_ROUNDS = 5;
    uint256 public constant WINS_REQUIRED = 3;
    uint256 public constant INITIAL_HEALTH = 9;
    uint256 public constant HEALTH_PER_LIFE = 3;
    uint256 public constant BPS_DENOMINATOR = 10_000; // 100%
    uint256 public constant MAX_ALLOWANCE = type(uint256).max;
    uint256 public constant ROLE_OPERATOR = _ROLE_0;

    // Interfaces
    IERC20 public immutable TOKEN_CONTRACT;
    IERC721 public immutable NFT_CONTRACT;

    // Storage
    uint256 private _current_game_id;
    mapping(uint256 => GameData) private _games;
    EnumerableSet.UintSet private _active_game_ids;
    mapping(uint256 => OnkaStats) private _onka_stats; // nft_id => stats

    uint256 private _revenue_bps = 200; // 2%
    bool private _revshare_enabled = true;
    address marketing_wallet;

    // Events
    event GameCreated(uint256 indexed game_id, Player[2] players, uint256 amount);
    event GameStarted(uint256 indexed game_id, uint64 sequence_number);
    event GameExecuted(uint256 indexed game_id);
    event GameCompleted(uint256 indexed game_id, bool indexed winner, RoundResult[BATTLE_ROUNDS] rounds);
    event GameAborted(uint256 indexed game_id);
    event BetPlaced(uint256 indexed game_id, address indexed addr, bool indexed prediction, uint256 amount);
    event CallbackOnInactiveGame(uint256 indexed game_id, GameStatus indexed status);
    event UserRegistered(bytes32 indexed secret, address indexed addr);
    event TokenNotSupported(address indexed token, string reason);

    // Errors
    error InvalidGame();
    error InvalidGameID();
    error InvalidAmount();
    error InvalidProvider();
    error InvalidPrediction();
    error InvalidNFTOwnership(address player, uint256 nft_id);
    error InvalidGameState(uint256 game_id, GameStatus current, GameStatus required);
    error InsufficientEntropyFee(uint256 fee_supplied, uint256 required);
    error InsufficientBalance(uint256 balance, uint256 required, address addr);
    error RegistrationFailed(string reason);

    constructor(address _nft_contract, address _token_contract, address _entropy, address _provider, address _marketing_wallet) {
        _initializeOwner(msg.sender);
        _grantRoles(msg.sender, ROLE_OPERATOR);
        NFT_CONTRACT = IERC721(_nft_contract);
        TOKEN_CONTRACT = IERC20(_token_contract);
        marketing_wallet = _marketing_wallet;
    }

    function get_current_game_id() external view returns (uint256) {
        return _current_game_id;
    }

    function get_active_game_ids() external view returns (uint256[] memory) {
        return _active_game_ids.values();
    }

    function get_game(uint256 game_id) external view returns (GameData memory) {
        if (game_id == 0 || game_id > _current_game_id) revert InvalidGameID();
        return _games[game_id];
    }

    function get_speculations(uint256 game_id) external view returns (Speculation[] memory) {
        if (game_id == 0 || game_id > _current_game_id) revert InvalidGameID();
        GameData storage game = _games[game_id];

        Speculation[] memory speculations = new Speculation[](game.speculations.length);
        for (uint256 i = 0; i < game.speculations.length; i++) {
            speculations[i] = Speculation(game.speculations[i].speculator, game.speculations[i].prediction, game.speculations[i].amount);
        }

        return speculations;
    }

    function get_onka_stats(uint256 nft_id) external view returns (OnkaStats memory) {
        return _onka_stats[nft_id];
    }



    function register(bytes32 secret) external {
        if (TOKEN_CONTRACT.allowance(msg.sender, address(this)) < MAX_ALLOWANCE) revert RegistrationFailed("Insufficient allowance");
        emit UserRegistered(secret, msg.sender);
    }

    function new_game(Player[2] memory players, uint256 amount) external payable onlyRolesOrOwner(ROLE_OPERATOR) returns (uint256 game_id) {
        // validate
        _validate_player(players[0]);
        _validate_player(players[1]);
        TOKEN_CONTRACT.transferFrom(players[0].addr, address(this), amount);
        TOKEN_CONTRACT.transferFrom(players[1].addr, address(this), amount);

        // new game
        _current_game_id++;
        game_id = _current_game_id;
        _games[game_id] = GameData({
            players: [Player(players[0].addr, players[0].nft_id), Player(players[1].addr, players[1].nft_id)],
            amount: amount,
            status: GameStatus.OPEN,
            speculations: new Speculation[](0),
            totalbet: 0
        });
        _active_game_ids.add(game_id);

        emit GameCreated(game_id, players, amount);
    }

    function place_bet(uint256 game_id, address speculator, bool prediction, uint256 amount) external onlyRolesOrOwner(ROLE_OPERATOR) {
        // validate
        GameData storage game = _get_validated_game(game_id, GameStatus.OPEN);

        // if (prediction > 1) revert InvalidPrediction();
        if (amount == 0) revert InvalidAmount();

        // transfer
        TOKEN_CONTRACT.transferFrom(speculator, address(this), amount);

        // save state
        game.speculations.push(Speculation({speculator: speculator, prediction: prediction, amount: amount}));
        game.totalbet += amount;

        emit BetPlaced(game_id, speculator, prediction, amount);
    }

    function start_game(uint256 game_id) external payable onlyRolesOrOwner(ROLE_OPERATOR) {
        // validate
        GameData storage game = _get_validated_game(game_id, GameStatus.OPEN);

        // request entropy
        uint128 request_fee = ENTROPY.getFee(PROVIDER);
        if (msg.value < request_fee) {
            revert InsufficientEntropyFee(msg.value, request_fee);
        }
        bytes32 user_random_number = keccak256(abi.encodePacked(game_id, game.players[0].addr, game.players[1].addr, block.timestamp));
        uint64 sequence_number = ENTROPY.requestWithCallback{value: request_fee}(PROVIDER, user_random_number);

        // save state
        game.status = GameStatus.ACTIVE;
        _entropy_cb_idx_to_game_id[sequence_number] = game_id;

        emit GameStarted(game_id, sequence_number);
    }

    // Entropy Callback
    function entropyCallback(uint64 sequence_number, address _provider, bytes32 random_number) internal override {
        // if (_provider != PROVIDER) revert InvalidProvider();
        uint256 game_id = _entropy_cb_idx_to_game_id[sequence_number];
        GameData storage game = _games[game_id];
        if (game.status != GameStatus.ACTIVE) {
            emit CallbackOnInactiveGame(game_id, game.status);
            return;
        }
        game.status = GameStatus.UNSETTLED;

        uint8 p1_wins = 0;
        uint8 p2_wins = 0;
        uint256 p1_health = INITIAL_HEALTH;
        uint256 p2_health = INITIAL_HEALTH;

        // Use the random number to generate multiple dice rolls
        bytes32 r = random_number;

        // Simulate rounds until one player wins 3 times
        for (uint256 round = 0; round < BATTLE_ROUNDS && p1_wins < WINS_REQUIRED && p2_wins < WINS_REQUIRED; round++) {
            // Generate two dice rolls (1-6) from the current random number
            // TODO: optimize
            r = keccak256(abi.encodePacked(r, round));
            uint8 diceRoll1 = uint8(uint256(r) % 6) + 1;
            r = keccak256(abi.encodePacked(r, round + 1));
            uint8 diceRoll2 = uint8(uint256(r) % 6) + 1;

            // reroll if tie
            while (diceRoll1 == diceRoll2) {
                r = keccak256(abi.encodePacked(r, "reroll"));
                diceRoll1 = uint8(uint256(r) % 6) + 1;
                r = keccak256(abi.encodePacked(r, "reroll2"));
                diceRoll2 = uint8(uint256(r) % 6) + 1;
            }

            bool player1WonRound = diceRoll1 > diceRoll2;

            // Record round result
            game.rounds.push(RoundResult({player1Roll: diceRoll1, player2Roll: diceRoll2, player1Won: player1WonRound}));

            // Update wins and health
            if (player1WonRound) {
                p1_wins++;
                p2_health = (WINS_REQUIRED - p1_wins) * HEALTH_PER_LIFE;
            } else {
                p2_wins++;
                p1_health = (WINS_REQUIRED - p2_wins) * HEALTH_PER_LIFE;
            }
        }

        game.p1_wins = p1_wins;
        game.p2_wins = p2_wins;

        // clean up
        delete _entropy_cb_idx_to_game_id[sequence_number];
        emit GameExecuted(game_id);
    }

    function end_game(uint256 game_id) external onlyRolesOrOwner(ROLE_OPERATOR) {
        // validate
        GameData storage game = _get_validated_game(game_id, GameStatus.UNSETTLED);

        // Determine winner (0 for player1, 1 for player2)
        uint8 winner = game.p1_wins > game.p2_wins ? 0 : 1;
        {
            // Update game state
            game.status = GameStatus.COMPLETED;

            // Handle payouts
            uint256 winnings = game.amount * 2;
            uint256 revenue;
            if (_revshare_enabled) {
                revenue = FPML.fullMulDiv(_revenue_bps, winnings, BPS_DENOMINATOR);
                winnings = winnings - revenue;
                // TOKEN_CONTRACT.transfer(marketing_wallet, revenue);
            }
            TOKEN_CONTRACT.transfer(game.players[winner].addr, winnings);

            // Handle speculation payouts

            // Calculate winning pool size
            uint256 winning_pool;
            uint256 bet_revenue = _revshare_enabled ? FPML.fullMulDiv(_revenue_bps, game.totalbet, BPS_DENOMINATOR) : 0;
            uint256 bet_pool = game.totalbet - bet_revenue;
            for (uint256 i = 0; i < game.speculations.length; i++) {
                if (game.speculations[i].prediction == winner) {
                    winning_pool += game.speculations[i].amount;
                }
            }

            // Transfer rewards proportionally
            if (winning_pool == 0 || winning_pool == game.totalbet) {
                _refund_speculations(game);
            } else {
                for (uint256 i = 0; i < game.speculations.length; i++) {
                    Speculation memory spec = game.speculations[i];
                    if (spec.prediction == winner) {
                        uint256 reward = (spec.amount / winning_pool) * bet_pool;
                        TOKEN_CONTRACT.transfer(spec.speculator, reward);
                    }
                }
            }
            if (_revshare_enabled) {
                TOKEN_CONTRACT.transfer(marketing_wallet, bet_revenue + revenue);
            }
        }
        RoundResult[BATTLE_ROUNDS] memory rounds;
        for (uint256 i = 0; i < game.rounds.length; i++) {
            rounds[i] = game.rounds[i];
        }
        _active_game_ids.remove(game_id);
        emit GameCompleted(game_id, winner, rounds);
    }

    function abort_game(uint256 game_id) external nonReentrant onlyRolesOrOwner(ROLE_OPERATOR) {
        // validate
        if (game_id == 0 || game_id > _current_game_id) revert InvalidGameID();
        GameData storage game = _games[game_id];
        if (game.status == GameStatus.COMPLETED || game.status == GameStatus.CANCELLED) return; // No-op if game is already completed or cancelled

        // process refunds
        for (uint32 i; i < 2; i++) {
            TOKEN_CONTRACT.transfer(game.players[i].addr, game.amount);
        }
        _refund_speculations(game);

        // save state
        game.status = GameStatus.CANCELLED;
        _active_game_ids.remove(game_id);

        emit GameAborted(game_id);
    }

    function setRevenueBPS(uint256 bps) external onlyOwner {
        _revenue_bps = bps;
    }

    function _validate_player(Player memory player) internal view {
        if (NFT_CONTRACT.ownerOf(player.nft_id) != player.addr) {
            revert InvalidNFTOwnership(player.addr, player.nft_id);
        }
    }

    function _get_validated_game(uint256 game_id, GameStatus expected) internal view returns (GameData storage) {
        if (game_id == 0 || game_id > _current_game_id) revert InvalidGameID();
        GameData storage game = _games[game_id];
        if (game.status != expected) revert InvalidGameState(game_id, game.status, expected);
        return game;
    }

    function _refund_speculations(GameData storage game) internal {
        for (uint256 i = 0; i < game.speculations.length; i++) {
            TOKEN_CONTRACT.transfer(game.speculations[i].speculator, game.speculations[i].amount);
        }
    }
}
