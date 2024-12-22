// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.26;

import {OwnableRoles} from "solady/auth/OwnableRoles.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {GameData, GameState, Player, Speculation, RoundResult} from "./lib/models.sol";
import {IEntropy} from "node_modules/@pythnetwork/entropy-sdk-solidity/IEntropy.sol";
import {IEntropyConsumer} from "node_modules/@pythnetwork/entropy-sdk-solidity/IEntropyConsumer.sol";
import {ERC2771Forwarder} from "@openzeppelin/contracts/metatx/ERC2771Forwarder.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {FixedPointMathLib as FPML} from "solady/utils/FixedPointMathLib.sol";

contract OnkasOujiGame is OwnableRoles, ERC2771Forwarder, IEntropyConsumer {
    // Storage
    uint256 private _current_game_id;
    mapping(uint256 => GameData) private _games;
    uint256 private _revenue_bps = 200; // 2%
    mapping(uint64 => uint256) private _entropy_cb_idx_to_game_id;
    bool private _revshare_enabled = true;
    address marketing_wallet;

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
    address public immutable PROVIDER;
    IEntropy public immutable ENTROPY;

    // Errors
    error InactiveGame();
    error InvalidGameID();
    error InvalidAmount();
    error InvalidProvider();
    error InvalidPrediction();
    error RegistrationFailed(string reason);
    error InvalidNFTOwnership(address player, uint256 nft_id);
    error InsufficientEntropyFee(uint256 fee, uint256 required);
    error InsufficientBalance(uint256 balance, uint256 required, address addr);

    // Events
    event GameCreated(uint256 indexed game_id, Player[2] players, uint256 amount);
    event GameStarted(uint256 indexed game_id, uint64 sequence_number);
    event GameCompleted(uint256 indexed game_id, uint8 winner, RoundResult[BATTLE_ROUNDS] rounds);
    event GameAborted(uint256 indexed game_id);
    event CallbackOnInactiveGame(uint256 indexed game_id, GameState state);
    event BetPlaced(uint256 indexed game_id, address indexed addr, uint8 prediction, uint256 amount);
    event UserRegistered(bytes32 indexed secret, address indexed addr);
    event TokenNotSupported(address token, string reason);

    constructor(address _nft_contract, address _token_contract, address _entropy, address _provider, address _marketing_wallet)
        ERC2771Forwarder("OnkasOujiGame")
    {
        _initializeOwner(msg.sender);
        _grantRoles(msg.sender, ROLE_OPERATOR);
        NFT_CONTRACT = IERC721(_nft_contract);
        TOKEN_CONTRACT = IERC20(_token_contract);
        ENTROPY = IEntropy(_entropy);
        PROVIDER = _provider;
        marketing_wallet = _marketing_wallet;
    }

    function register(bytes32 secret) external {
        if (TOKEN_CONTRACT.allowance(msg.sender, address(this)) < MAX_ALLOWANCE) revert RegistrationFailed("Insufficient allowance");
        emit UserRegistered(secret, msg.sender);
    }

    function new_game(Player[2] memory players, uint256 amount) external payable onlyRolesOrOwner(ROLE_OPERATOR) returns (uint256 game_id) {
        // Validate
        for (uint32 i; i < 2; i++) {
            if (NFT_CONTRACT.ownerOf(players[i].nft_id) != players[i].addr) {
                revert InvalidNFTOwnership(players[i].addr, players[i].nft_id);
            }
            TOKEN_CONTRACT.transferFrom(players[i].addr, address(this), amount);
        }

        // Increment game ID
        _current_game_id++;
        game_id = _current_game_id;

        // Create new game
        GameData storage game = _games[game_id];

        // Set game data
        game.players[0] = Player(players[0].addr, players[0].nft_id);
        game.players[1] = Player(players[1].addr, players[1].nft_id);
        game.amount = amount;
        game.state = GameState.OPEN;

        emit GameCreated(game_id, players, amount);
    }

    function place_bet(uint256 game_id, address speculator, uint8 prediction, uint256 amount) external onlyRolesOrOwner(ROLE_OPERATOR) {
        // Validate game ID
        if (game_id == 0 || game_id > _current_game_id) revert InvalidGameID();
        GameData storage game = _games[game_id];
        if (game.state != GameState.OPEN) revert InactiveGame();

        // Validate prediction (must be 0 or 1), amount > 0
        if (prediction > 1) revert InvalidPrediction();
        if (amount == 0) revert InvalidAmount();

        // Transfer tokens from speculator to contract
        TOKEN_CONTRACT.transferFrom(speculator, address(this), amount);

        // Add speculation to game
        game.speculations.push(Speculation({speculator: speculator, prediction: prediction, amount: amount}));
        game.totalbet += amount;

        emit BetPlaced(game_id, speculator, prediction, amount);
    }

    function start_game(uint256 game_id) external payable onlyRolesOrOwner(ROLE_OPERATOR) {
        // Validate
        if (game_id == 0 || game_id > _current_game_id) revert InvalidGameID();
        GameData storage game = _games[game_id];
        if (game.state != GameState.OPEN) revert InactiveGame();

        // Get the required fee
        uint128 requestFee = ENTROPY.getFee(PROVIDER);
        if (msg.value < requestFee) revert InsufficientEntropyFee(msg.value, requestFee); // tODO: maybe also check existing balance

        // Generate user random number (using game details as entropy)
        bytes32 userRandomNumber = keccak256(abi.encodePacked(game_id, game.players[0].addr, game.players[1].addr, block.timestamp));

        // Request random number from Entropy
        game.state = GameState.ACTIVE;
        uint64 sequenceNumber = ENTROPY.requestWithCallback{value: requestFee}(PROVIDER, userRandomNumber);

        // Store game ID for the callback
        _entropy_cb_idx_to_game_id[sequenceNumber] = game_id;

        emit GameStarted(game_id, sequenceNumber);
    }

    // Implement required interface method
    function getEntropy() internal view override returns (address) {
        return address(ENTROPY);
    }

    // Callback implementation
    function entropyCallback(uint64 sequence_number, address _provider, bytes32 random_number) internal override {
        // if (_providerAddress != PROVIDER) revert InvalidProvider();
        uint256 game_id = _entropy_cb_idx_to_game_id[sequence_number];
        GameData storage game = _games[game_id];
        if (game.state != GameState.ACTIVE) {
            emit CallbackOnInactiveGame( game_id,game.state);
            return;
        }

        // Ensure game exists and is still open
        // require(game.state == GameState.OPEN, "Game: Invalid game state");

        uint8 player1Wins = 0;
        uint8 player2Wins = 0;
        uint256 player1Health = INITIAL_HEALTH;
        uint256 player2Health = INITIAL_HEALTH;

        // Use the random number to generate multiple dice rolls
        bytes32 currentRandom = random_number;

        // Simulate rounds until one player wins 3 times
        for (uint256 round = 0; round < BATTLE_ROUNDS && player1Wins < WINS_REQUIRED && player2Wins < WINS_REQUIRED; round++) {
            // Generate two dice rolls (1-6) from the current random number
            currentRandom = keccak256(abi.encodePacked(currentRandom, round));
            uint8 diceRoll1 = uint8(uint256(currentRandom) % 6) + 1;
            currentRandom = keccak256(abi.encodePacked(currentRandom, round + 1));
            uint8 diceRoll2 = uint8(uint256(currentRandom) % 6) + 1;

            // Reroll if it's a tie (similar to MVP logic)
            while (diceRoll1 == diceRoll2) {
                currentRandom = keccak256(abi.encodePacked(currentRandom, "reroll"));
                diceRoll1 = uint8(uint256(currentRandom) % 6) + 1;
                currentRandom = keccak256(abi.encodePacked(currentRandom, "reroll2"));
                diceRoll2 = uint8(uint256(currentRandom) % 6) + 1;
            }

            bool player1WonRound = diceRoll1 > diceRoll2;

            // Record round result
            game.rounds.push(RoundResult({player1Roll: diceRoll1, player2Roll: diceRoll2, player1Won: player1WonRound}));

            // Update wins and health
            if (player1WonRound) {
                player1Wins++;
                player2Health = (WINS_REQUIRED - player1Wins) * HEALTH_PER_LIFE;
            } else {
                player2Wins++;
                player1Health = (WINS_REQUIRED - player2Wins) * HEALTH_PER_LIFE;
            }
        }

        game.player1Wins = player1Wins;
        game.player2Wins = player2Wins;

        // Determine winner (0 for player1, 1 for player2)
        uint8 winner = player1Wins > player2Wins ? 0 : 1;
        {
            // Update game state
            game.state = GameState.COMPLETED;

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
            if (winning_pool == game.totalbet) {
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
            if (_revshare_enabled) TOKEN_CONTRACT.transfer(marketing_wallet, bet_revenue + revenue);
        }

        // Clean up
        delete _entropy_cb_idx_to_game_id[sequence_number];

        RoundResult[BATTLE_ROUNDS] memory roundsArray;
        for (uint256 i = 0; i < game.rounds.length; i++) {
            roundsArray[i] = game.rounds[i];
        }
        emit GameCompleted(game_id, winner, roundsArray);
    }

    function abort_game(uint256 game_id) external onlyRolesOrOwner(ROLE_OPERATOR) {
        // Validate game ID
        if (game_id == 0 || game_id > _current_game_id) revert InvalidGameID();
        GameData storage game = _games[game_id];
        if (game.state == GameState.COMPLETED || game.state == GameState.CANCELLED) return; // No-op if game is already completed or cancelled

        // Set game state to CANCELLED
        game.state = GameState.CANCELLED;

        // Refund players
        for (uint32 i; i < 2; i++) {
            TOKEN_CONTRACT.transfer(game.players[i].addr, game.amount);
        }

        _refund_speculations(game);

        emit GameAborted(game_id);
    }

    function get_current_game_id() external view returns (uint256) {
        return _current_game_id;
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

    function setRevenueBPS(uint256 bps) external onlyOwner {
        _revenue_bps = bps;
    }

    function _refund_speculations(GameData storage game) internal {
        for (uint256 i = 0; i < game.speculations.length; i++) {
            TOKEN_CONTRACT.transfer(game.speculations[i].speculator, game.speculations[i].amount);
        }
    }
}
