// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.26;

/**
 * @title OnkasOujiGame
 * @notice The Onka Ouji Game
 * @author Sambot (https://github.com/nomad-lw/OnkasOuji/blob/main/src/RandomSourcer.sol)
 * @dev
 *
 *  .                                                                   .,
 *                             ii                                     ;LL.
 *                            ;LLi                                   :LfL;
 *                            tLLf.                                 .fLfL:
 *                           .fLfL;                                 1LfLf.
 *                           ;LffLt                                ;LfLLf.
 *                           tLfLfL,                              .fLffLf.
 *                           tLfLfL1                              1LfLfLf.
 *                          :LfLLLLf.                            ;LfLLfLf.
 *                          :LfLLLfL;.,,:;;;;i1111111ttt1111111i;fLfLLLLL,
 *                          tLfLLLLLffLLLLLLLLLLLLLLLLLLLLLLLLLLLLfLLLLLLft1i:,
 *                      .:itfLLLLLLLLLLfffffffffffffffffffffffffffLLLLLLLLLLLLLf1;,
 *                   .;1fLLLLLLLLLLLfLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLfffffLLLLLf1:.
 *                 ,1fLLLfffLLLLLLLLfLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLffffLLLf1,
 *              .;tLLLfffLLLLLLLLLLLfLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLfffLLLt;.
 *             :fLLffLLLLLLLLLLLLLLLfLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLfffLCf;
 *           .tLLffLLLLLLLLLLLLLLLLLfLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLfLi1L1.
 *          :fLffLLLLLLLLLLLLLLLLLLLfLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLfL1. ;Lf,
 *         ;LLfLLLLLfffffffffLLLLLLLfLLLLLLLLLLLLfffffffffffffffffffffLLLLLLLLLLLLLLLLLfL.   fLf.
 *        ,LLfLLLLLfLLLLLLLLLLLLffffffffffffffLLLLLLLLLLLLLLLLLLLLLLLLfLLLLLLLLLLLLLLLfLf,   ;LLt
 *        tLfLLLLLLL1i1111ftffLLLLLLLLLLLLLLLLLLLffft1111;;;i:::::::ifLfLLLLLLLLLLLLLLfLt    :Lff.
 *       :LfLLLLLfLi         ...,::;i;;;;::::,....                    ;LfLLLLLLLLLLLLLfLf.   :Lff.
 *       ,LffLLLLfL:                                                   iLfLLLLLLLLLLLLfLt.   :fLt
 *        iLffLLLfL;                                                    fLfLLLLLLLLLLLfLf.   1Ct.
 *         ;LLfLLfLt                                      ...,::::,..   tLfLLLLLLLLLLLfLf.  :Lt.
 *          :LLfLLfL:  .:i;;i;:,                        :t111iiiitf1,  :LfLLLLLLLLLLLLfLf. ,Li
 *           :fLLffLf, :i:::::::                 .,::f:               .tLfLLLLLLLLLLLffLf:i1:
 *             ifLLfLf,                  ::,,,:;;;i:if.              ,tLfLLLLLLLLffffLLLLt:
 *              .;tLLLLi.                :iii;;;;::::.             ,1fLfLfffffffLLLLLf1:.
 *                 :1tLCL1;,.                                .,:;1tLLffLLLLLLLLLft1;,
 *                    ,:1fLLfft11i;:::::::,,,,,,:;;;;;;i11ttffLCCCLLLLLLLfft1i;,.
 *                         .,::iii1tttttftLLLLLLLLLLLLLLLLLLLf1;;:::::,..
 *                                      ,1fLffffffffffffffffLff1,
 *                                    ,iLLLfLLLLLLLLLLLLLLLLLLLLLt,
 *                                   iLLLLfLLLLLLLLLLLLLLLLLLL1fLLL;
 *                                 ,fLfLf:1LfLLLLLLLLLLLLLLLfLt.fLLCt
 *                                it1fL1.,LfLLLLLLLLLLLLLLLLfLt .tftLt.
 *                              :fLffLt  tLfLLLLLLLLLLLLLLLLLLf, .ttfLf;
 *                             :LLffLf, ,LffffffffffffffffffLfL;  ;LffLLi
 *                            :LLLLLf,  1LLLLLLLLLLLLLLLLLLLLLLt   1LLLLC1
 *                           .ffffff:  .ffffffffffffffffffffffff,   tfffffi
 */

// Core imports
import {Wyrd} from "./Wyrd.sol";

// Interface imports
import {IOnkasOujiGame} from "./interfaces/IOnkasOujiGame.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Library imports
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {FixedPointMathLib as FPML} from "solady/utils/FixedPointMathLib.sol";
import {SafeTransferLib as STL} from "solady/utils/SafeTransferLib.sol";

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

    /* ▀▀▀ Errors ▀▀▀ */
    error InvalidGame();
    error InvalidGameID();
    error InvalidAmount();
    error InvalidInput();
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
    ) Wyrd(7, _provider, _entropy, _provider, _sav_pk, false) {
        if (
            _nft_contract == address(0) || _token_contract == address(0) || _entropy == address(0) || _provider == address(0)
                || _marketing_wallet == address(0)
        ) {
            revert InvalidInput();
        }

        _initializeOwner(msg.sender);
        _grantRoles(msg.sender, ROLE_OPERATOR);
        NFT_CONTRACT = IERC721(_nft_contract);
        TOKEN_CONTRACT = IERC20(_token_contract);
        marketing_wallet = _marketing_wallet;
    }

    /* ▀▀▀ View/Pure Functions ▀▀▀ */

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

    function get_alpha(uint256 game_id) public view override returns (bytes32) {
        return compute_alpha(game_id);
    }

    /**
     * @notice Calculates the current state of the betting book for a particular game
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

        p1_depth = 0;
        p2_depth = 0;

        // calc depths
        unchecked {
            for (uint256 i; i < specs_length; ++i) {
                if (specs[i].prediction) {
                    p1_depth += specs[i].amount;
                } else {
                    p2_depth += specs[i].amount;
                }
            }
        }

        // calc odds
        if (p1_depth != 0 && p2_depth != 0) {
            p1_odds = FPML.divWad(p1_depth, p2_depth);
            p2_odds = FPML.divWad(p2_depth, p1_depth);
        } else {
            // single-sided is no-op
            p1_odds = 0;
            p2_odds = 0;
        }
    }

    /* ▀▀▀ ??? ▀▀▀ */

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
        if (players[0].nft_id == players[1].nft_id) revert InvalidInput(); // no onka can play itself

        STL.safeTransferFrom(address(TOKEN_CONTRACT), players[0].addr, address(this), amount);
        STL.safeTransferFrom(address(TOKEN_CONTRACT), players[1].addr, address(this), amount);

        // new game
        _current_game_id++;
        game_id = _current_game_id;
        _games[game_id] = GameData({
            players: [Player(players[0].addr, players[0].nft_id), Player(players[1].addr, players[1].nft_id)],
            amount: amount,
            status: GameStatus.OPEN,
            speculations: new Speculation[](0),
            bet_pool: 0,
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
        STL.safeTransferFrom(address(TOKEN_CONTRACT), speculator, address(this), amount);

        // save state
        game.speculations.push(Speculation({speculator: speculator, prediction: prediction, amount: amount}));
        game.bet_pool += amount;

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

    function exec_game(uint256 game_id, bytes32 random_number) public onlyRolesOrOwner(ROLE_OPERATOR) {
        GameData storage game = _get_validated_game(game_id, GameStatus.ACTIVE);
        game.status = GameStatus.UNSETTLED;
        uint8 p1_wins = 0;
        uint8 p2_wins = 0;
        // uint256 p1_health = INITIAL_HEALTH;
        // uint256 p2_health = INITIAL_HEALTH;
        bytes32 r = random_number;
        RoundResult[] memory rounds = new RoundResult[](BATTLE_ROUNDS);
        // Simulate rounds until one player wins 3 times
        for (uint8 round; round < BATTLE_ROUNDS && p1_wins < WINS_REQUIRED && p2_wins < WINS_REQUIRED; ++round) {
            // Generate two dice rolls (1-6) from the current random number
            // TODO: optimize, maybe switch to XOR
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

            // wins and health
            if (roll_w0) {
                p1_wins++;
                // p2_health = (WINS_REQUIRED - p1_wins) * HEALTH_PER_LIFE;
            } else {
                p2_wins++;
                // p1_health = (WINS_REQUIRED - p2_wins) * HEALTH_PER_LIFE;
            }
            rounds[round] = RoundResult({roll_p1: roll_p1, roll_p2: roll_p2, p1_won: roll_w0});
        }

        uint8 rounds_played = p1_wins + p2_wins;
        RoundResult[] memory actual_rounds = new RoundResult[](rounds_played);
        unchecked {
            for (uint8 i = 0; i < rounds_played; i++) {
                actual_rounds[i] = rounds[i];
            }
        }

        game.rounds = actual_rounds;
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
        bool w0 = game.p1_wins > game.p2_wins ? true : false; // winner idx (0 for p1, 1 for p2)

        // calculate rake, winnings (players&speculators)
        // bet payouts = if one-sided pool, refund. else, payout_pool = pool - rake, distribute proportional to winner weight
        uint256 player_payout = game.amount * 2;
        uint256 player_rake;
        uint256 bet_rake;
        uint256 pool = game.bet_pool;

        (uint256 p1_odds, uint256 p2_odds, uint256 p1_depth, uint256 p2_depth) = calc_book(game_id);
        bool valid_pool = pool != 0 && p1_odds != 0 && p2_odds != 0; // or p1_depth != 0 && p2_depth != 0, simpler
        uint256 winning_pool = w0 ? p1_depth : p2_depth;

        if (_revshare_enabled) {
            player_rake = FPML.fullMulDiv(player_payout, _bps_revenue, BPS_DENOMINATOR);
            bet_rake = valid_pool ? FPML.fullMulDiv(pool, _bps_revenue, BPS_DENOMINATOR) : 0;
            player_payout -= player_rake;
            pool -= bet_rake;
        }

        _games[game_id].status = GameStatus.COMPLETED;
        _active_game_ids.remove(game_id);

        // payouts
        STL.safeTransfer(address(TOKEN_CONTRACT), game.players[w0 ? 0 : 1].addr, player_payout);
        if (!valid_pool) {
            _refund_speculations(_games[game_id]);
        } else {
            Speculation[] memory specs = game.speculations;
            uint256 spec_length = specs.length;
            for (uint256 i; i < spec_length; ++i) {
                if (specs[i].prediction == w0) {
                    uint256 weight = FPML.divWad(specs[i].amount, winning_pool);
                    uint256 payout = FPML.mulWad(pool, weight);
                    STL.safeTransfer(address(TOKEN_CONTRACT), specs[i].speculator, payout);
                }
            }
        }
        if (_revshare_enabled) STL.safeTransfer(address(TOKEN_CONTRACT), marketing_wallet, bet_rake + player_rake);

        // event
        uint8 rlen = uint8(game.rounds.length);
        RoundResult[BATTLE_ROUNDS] memory rounds;
        for (uint8 i; i < rlen; ++i) {
            rounds[i] = game.rounds[i];
        }
        emit GameCompleted(game_id, uint8(w0 ? 0 : 1), rounds);
    }

    function abort_game(uint256 game_id) external nonReentrant onlyRolesOrOwner(ROLE_OPERATOR) {
        // validate
        if (game_id == 0 || game_id > _current_game_id) revert InvalidGameID();
        GameData storage game = _games[game_id];
        GameStatus status = game.status;
        uint256 amount = game.amount;
        if (status == GameStatus.COMPLETED || status == GameStatus.CANCELLED) return; // No-op if game completed or cancelled

        // save state
        game.status = GameStatus.CANCELLED;
        _active_game_ids.remove(game_id);

        // process refunds
        STL.safeTransfer(address(TOKEN_CONTRACT), game.players[0].addr, amount);
        STL.safeTransfer(address(TOKEN_CONTRACT), game.players[1].addr, amount);
        _refund_speculations(game);

        emit GameAborted(game_id);
    }

    function set_marketing_address(address addr) external onlyOwner {
        marketing_wallet = addr;
    }

    function set_revenue(uint256 bps) external onlyOwner {
        _bps_revenue = bps;
    }

    function _validate_player(Player memory player) internal view {
        try NFT_CONTRACT.ownerOf(player.nft_id) returns (address owner) {
            if (owner != player.addr) revert InvalidNFTOwnership(player.addr, player.nft_id);
        } catch {
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
                STL.safeTransfer(address(TOKEN_CONTRACT), specs[i].speculator, specs[i].amount);
            }
        }
    }
}
