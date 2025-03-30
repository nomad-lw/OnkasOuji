// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.26;

import {IWyrd} from "./IWyrd.sol";
import {GameData, GameStatus, Player, Speculation, RoundResult, OnkaStats} from "../lib/models.sol";

interface IOnkasOujiGame is IWyrd {
    // === Events ===
    // event GameCreated(uint256 indexed game_id, Player[2] players, uint256 amount);
    // event GameStarted(uint256 indexed game_id);
    // event GameExecuted(uint256 indexed game_id);
    // event GameCompleted(uint256 indexed game_id, uint8 indexed winner, RoundResult[] rounds);
    // event GameAborted(uint256 indexed game_id);
    // event BetPlaced(uint256 indexed game_id, address indexed addr, bool indexed prediction, uint256 amount);
    // event UserRegistered(bytes32 indexed secret, address indexed addr);

    // === View Functions ===
    function get_current_game_id() external view returns (uint256);
    function get_active_game_ids() external view returns (uint256[] memory);
    function get_game(uint256 game_id) external view returns (GameData memory);
    function get_speculations(uint256 game_id) external view returns (Speculation[] memory);
    function get_onka_stats(uint256 nft_id) external view returns (OnkaStats memory);
    function calc_book(uint256 game_id) external view returns (uint256 p1_odds, uint256 p2_odds, uint256 p1_depth, uint256 p2_depth);

    // === External Functions ===
    function register(bytes32 secret) external;
    function new_game(Player[2] memory players, uint256 amount, bytes32 alpha_prefix) external payable returns (uint256);
    function place_bet(uint256 game_id, address speculator, bool prediction, uint256 amount) external;
    function start_game(uint256 game_id) external payable;
    function end_game(uint256 game_id) external;
    function abort_game(uint256 game_id) external;
    function set_revenue_address(address addr) external;
    function set_revenue(uint256 bps) external;
}
