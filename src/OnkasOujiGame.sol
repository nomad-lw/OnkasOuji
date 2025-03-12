// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.26;

// Core imports
import {Wyrd} from "./Wyrd.sol";

// Interface imports
import {IOnkasOujiGame} from "./interfaces/IOnkasOujiGame.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Library imports
import {FixedPointMathLib as FPML} from "solady/utils/FixedPointMathLib.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

// Local imports
import {GameData, GameStatus, Player, Speculation, RoundResult, OnkaStats} from "./lib/models.sol";

contract OnkasOujiGame is IOnkasOujiGame, Wyrd {
    using EnumerableSet for EnumerableSet.UintSet;

    // Constants
    uint256 public constant BATTLE_ROUNDS = 5;
    uint256 public constant WINS_REQUIRED = 3;
    uint256 public constant INITIAL_HEALTH = 9;
    uint256 public constant HEALTH_PER_LIFE = 3;
    uint256 internal constant BPS_DENOMINATOR = 10_000; // 100%
    uint256 internal constant MAX_ALLOWANCE = type(uint256).max;
    // uint256 internal constant ROLE_OPERATOR = _ROLE_0;

    // Interfaces
    IERC20 public immutable TOKEN_CONTRACT;
    IERC721 public immutable NFT_CONTRACT;

    // Storage
    uint256 private _current_game_id;
    mapping(uint256 => GameData) private _games;
    EnumerableSet.UintSet private _active_game_ids;
    mapping(uint256 => OnkaStats) private _onka_stats; // nft_id => stats

    uint256 private _bps_revenue = 200; // 2%
    bool private _revshare_enabled = true;
    address public marketing_wallet;

    // Events
    event GameCreated(uint256 indexed game_id, Player[2] players, uint256 amount);
    event GameStarted(uint256 indexed game_id);
    event GameExecuted(uint256 indexed game_id);
    event GameCompleted(uint256 indexed game_id, uint8 indexed winner, RoundResult[BATTLE_ROUNDS] rounds);
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
    error InvalidGameStatus(uint256 game_id, GameStatus current, GameStatus required);

    error InsufficientBalance(uint256 balance, uint256 required, address addr);
    error RegistrationFailed(string reason);

    constructor(
        address _nft_contract,
        address _token_contract,
        address _entropy,
        address _provider,
        address _marketing_wallet,
        uint256[2] memory _sav_pk
    ) Wyrd(7, _provider, _entropy, _provider, _sav_pk) {
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

    function compute_alpha(uint256 game_id) public view returns (bytes32) {
        if (game_id == 0 || game_id > _current_game_id) revert InvalidGameID();
        return compute_alpha(game_id, _games[game_id]);
    }

    function compute_alpha(uint256 game_id, GameData storage game) internal view returns (bytes32) {
        return game.alpha_prefix ^ bytes32(uint256(uint160(game.players[0].addr) ^ uint160(game.players[1].addr)) ^ game_id);
    }

    /**
     * @notice Calculates the betting book for a particular game
     * @dev In sports betting and gambling terminology, a "book" refers to the collection
     * of all bets (speculations) placed on an event, along with the odds and liquidity
     * for each side. This function calculates the current state of the betting book,
     * including odds and market depth (liquidity) for each player.
     * @param game_id The ID of the game to calculate the book for
     * @return p1_odds The odds for player 1 (ratio of p1_depth to p2_depth)
     * @return p2_odds The odds for player 2 (ratio of p2_depth to p1_depth)
     * @return p1_depth The total amount bet on player 1's victory
     * @return p2_depth The total amount bet on player 2's victory
     */
    function calc_book(uint256 game_id) public view returns (uint256 p1_odds, uint256 p2_odds, uint256 p1_depth, uint256 p2_depth) {
        if (game_id == 0 || game_id > _current_game_id) revert InvalidGameID();
        Speculation[] memory specs = _games[game_id].speculations;
        uint256 specs_length = specs.length;

        // Initialize depths
        p1_depth = 0;
        p2_depth = 0;

        // Single loop to calculate depths
        unchecked {
            // Safe because we're only adding positive amounts
            for (uint256 i; i < specs_length; ++i) {
                if (specs[i].prediction) {
                    p1_depth += specs[i].amount;
                } else {
                    p2_depth += specs[i].amount;
                }
            }
        }

        // Calculate odds
        if (p1_depth != 0 && p2_depth != 0) {
            p1_odds = FPML.divWad(p1_depth, p2_depth);
            p2_odds = FPML.divWad(p2_depth, p1_depth);
        } else {
            // single-sided is no-op
            p1_odds = 0;
            p2_odds = 0;
        }
    }

    function register(bytes32 secret) external {
        if (TOKEN_CONTRACT.allowance(msg.sender, address(this)) < MAX_ALLOWANCE) {
            revert RegistrationFailed("Insufficient allowance");
        }
        emit UserRegistered(secret, msg.sender);
    }

    function new_game(Player[2] memory players, uint256 amount, bytes32 alpha_prefix)
        external
        payable
        onlyRolesOrOwner(ROLE_OPERATOR)
        returns (uint256 game_id)
    {
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
            handle: 0,
            p1_wins: 0,
            p2_wins: 0,
            rounds: new RoundResult[](5),
            alpha_prefix: alpha_prefix
        });
        _active_game_ids.add(game_id);

        emit GameCreated(game_id, players, amount);
    }

    function place_bet(uint256 game_id, address speculator, bool prediction, uint256 amount) external onlyRolesOrOwner(ROLE_OPERATOR) {
        // validate
        GameData storage game = _get_validated_game(game_id, GameStatus.OPEN);

        // transfer
        if (amount == 0) revert InvalidAmount();
        TOKEN_CONTRACT.transferFrom(speculator, address(this), amount);

        // save state
        game.speculations.push(Speculation({speculator: speculator, prediction: prediction, amount: amount}));
        game.handle += amount;

        emit BetPlaced(game_id, speculator, prediction, amount);
    }

    function start_game(uint256 game_id) external payable onlyRolesOrOwner(ROLE_OPERATOR) {
        // validate
        GameData storage game = _get_validated_game(game_id, GameStatus.OPEN);

        // save state & request random numbr
        (uint256 request_fee,,) = calc_fee();
        if (msg.value < request_fee) {
            revert InsufficientFee(msg.value, request_fee);
        }
        game.status = GameStatus.ACTIVE;
        _request_random(game_id, compute_alpha(game_id, game));

        emit GameStarted(game_id);
    }

    function exec_game(uint256 game_id, bytes32 random_number) public {
        GameData storage game = _get_validated_game(game_id, GameStatus.ACTIVE);
        game.status = GameStatus.UNSETTLED;
        uint8 p1_wins = 0;
        uint8 p2_wins = 0;
        uint256 p1_health = INITIAL_HEALTH;
        uint256 p2_health = INITIAL_HEALTH;
        bytes32 r = random_number;
        RoundResult[] memory rounds = new RoundResult[](BATTLE_ROUNDS);
        // Simulate rounds until one player wins 3 times
        for (uint8 round; round < BATTLE_ROUNDS && p1_wins < WINS_REQUIRED && p2_wins < WINS_REQUIRED; ++round) {
            // Generate two dice rolls (1-6) from the current random number
            // TODO: optimize
            r = keccak256(abi.encodePacked(r, round));
            uint8 roll_p1 = uint8(uint256(r) % 6) + 1;
            r = keccak256(abi.encodePacked(r, round + 1));
            uint8 roll_p2 = uint8(uint256(r) % 6) + 1;

            // reroll if tie
            while (roll_p1 == roll_p2) {
                r = keccak256(abi.encodePacked(r, "reroll"));
                roll_p1 = uint8(uint256(r) % 6) + 1;
                r = keccak256(abi.encodePacked(r, "reroll2"));
                roll_p2 = uint8(uint256(r) % 6) + 1;
            }

            bool roll_w0 = roll_p1 > roll_p2;

            // Record round result
            rounds[round] = RoundResult({roll_p1: roll_p1, roll_p2: roll_p2, p1_won: roll_w0});

            // Update wins and health
            if (roll_w0) {
                p1_wins++;
                p2_health = (WINS_REQUIRED - p1_wins) * HEALTH_PER_LIFE;
            } else {
                p2_wins++;
                p1_health = (WINS_REQUIRED - p2_wins) * HEALTH_PER_LIFE;
            }
        }
        game.rounds = rounds;
        game.p1_wins = p1_wins;
        game.p2_wins = p2_wins;

        bool w0 = p1_wins > p2_wins;

        // update onka stats
        _onka_stats[game.players[0].nft_id].plays += 1;
        _onka_stats[game.players[1].nft_id].plays += 1;
        _onka_stats[game.players[w0 ? 0 : 1].nft_id].wins += 1;
        _onka_stats[game.players[w0 ? 1 : 0].nft_id].losses += 1;

        // clean up
        emit GameExecuted(game_id);
    }

    function end_game(uint256 game_id) public nonReentrant onlyRolesOrOwner(ROLE_OPERATOR) {
        // validate
        GameData memory game = _get_validated_game(game_id, GameStatus.UNSETTLED);

        // Determine winner (0 for p1, 1 for p2)
        bool w0 = game.p1_wins > game.p2_wins ? true : false;

        _games[game_id].status = GameStatus.COMPLETED;
        // calculate rake, winnings (players&speculators)
        {
            // Handle payouts
            // player payouts = 2 player game amount - rake
            // bet payouts = if one-sided pool, refund. else, payout_pool = sidepool - rake, distribute proportional to winner pool weight
            uint256 player_payout = game.amount * 2;
            // uint256 sidepool = game.handle;
            uint256 player_rake;
            uint256 bet_rake;
            // uint256 sidepool_payout;
            uint256 handle = game.handle;

            (uint256 p1_odds, uint256 p2_odds, uint256 p1_depth, uint256 p2_depth) = calc_book(game_id);
            bool valid_handle = handle != 0 && p1_odds != 0 && p2_odds != 0;
            uint256 winning_pool = w0 ? p1_depth : p2_depth;

            if (_revshare_enabled) {
                player_rake = FPML.fullMulDiv(player_payout, _bps_revenue, BPS_DENOMINATOR);
                bet_rake = valid_handle ? FPML.fullMulDiv(handle, _bps_revenue, BPS_DENOMINATOR) : 0;

                player_payout -= player_rake;
                handle -= bet_rake;
            }
            TOKEN_CONTRACT.transfer(game.players[w0 ? 0 : 1].addr, player_payout);

            // Handle speculation payouts

            if (!valid_handle) {
                _refund_speculations(_games[game_id]);
            } else {
                Speculation[] memory specs = game.speculations;
                uint256 spec_length = specs.length;
                for (uint256 i; i < spec_length; ++i) {
                    if (specs[i].prediction == w0) {
                        uint256 weight = FPML.divWad(specs[i].amount, winning_pool);
                        uint256 payout = FPML.mulWad(handle, weight);
                        TOKEN_CONTRACT.transfer(specs[i].speculator, payout);
                    }
                }
            }

            if (_revshare_enabled) {
                TOKEN_CONTRACT.transfer(marketing_wallet, bet_rake + player_rake);
            }
        }
        RoundResult[BATTLE_ROUNDS] memory rounds;
        uint256 r_len = game.rounds.length;
        for (uint8 i; i < r_len; ++i) {
            rounds[i] = game.rounds[i];
        }
        _active_game_ids.remove(game_id);
        emit GameCompleted(game_id, uint8(w0 ? 0 : 1), rounds);
    }

    function abort_game(uint256 game_id) external nonReentrant onlyRolesOrOwner(ROLE_OPERATOR) {
        // validate
        if (game_id == 0 || game_id > _current_game_id) revert InvalidGameID();
        GameData storage game = _games[game_id];
        GameStatus status = game.status;
        uint256 amount = game.amount;
        if (status == GameStatus.COMPLETED || status == GameStatus.CANCELLED) return; // No-op if game completed or cancelled

        // process refunds
        TOKEN_CONTRACT.transfer(game.players[0].addr, amount); // TODO: review gas?
        TOKEN_CONTRACT.transfer(game.players[1].addr, amount);
        _refund_speculations(game);

        // save state
        game.status = GameStatus.CANCELLED;
        _active_game_ids.remove(game_id);

        emit GameAborted(game_id);
    }

    function set_marketing_address(address addr) external onlyOwner {
        marketing_wallet = addr;
    }

    function set_revenue(uint256 bps) external onlyOwner {
        _bps_revenue = bps;
    }

    function _validate_player(Player memory player) internal view {
        if (NFT_CONTRACT.ownerOf(player.nft_id) != player.addr) {
            revert InvalidNFTOwnership(player.addr, player.nft_id);
        }
    }

    function _get_validated_game(uint256 game_id, GameStatus expected) internal view returns (GameData storage) {
        if (game_id == 0 || game_id > _current_game_id) revert InvalidGameID();
        GameData storage game = _games[game_id];
        if (game.status != expected) revert InvalidGameStatus(game_id, game.status, expected);
        return game;
    }

    function _refund_speculations(GameData storage game) internal {
        Speculation[] memory specs = game.speculations;
        uint256 length = specs.length;
        unchecked {
            for (uint256 i; i < length; ++i) {
                TOKEN_CONTRACT.transfer(specs[i].speculator, specs[i].amount);
            }
        }
    }
}
