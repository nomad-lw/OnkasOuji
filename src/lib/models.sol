// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.26;

enum GameStatus {
    OPEN,
    ACTIVE,
    UNSETTLED,
    COMPLETED,
    CANCELLED
}

struct Player {
    address addr;
    uint256 nft_id;
}

struct Speculation {
    address speculator;
    bool prediction; // 0 p1, 1 p2
    uint256 amount; // Bet amount
}

struct GameData {
    Player[2] players;
    Speculation[] speculations;
    uint256 amount;
    GameStatus status;
    RoundResult[] rounds;
    uint8 p1_wins;
    uint8 p2_wins;
    uint256 bet_pool; // bet pool sans player stakes
    bytes32 alpha_prefix;
}

struct RoundResult {
    uint8 roll_p1;
    uint8 roll_p2;
    bool p1_won;
}

struct OnkaStats {
    uint256 plays;
    uint256 wins;
    uint256 losses;
}

enum TestGameTypes {
    STANDARD,
    NO_SPECULATION,
    TWO_SPECULATIONS,
    ABORT_NO_SPECULATION,
    ABORT_WITH_SPECULATION,
    NO_APPROVAL
}
