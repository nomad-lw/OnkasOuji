// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.26;

enum GameState {
    OPEN,
    ACTIVE,
    COMPLETED,
    CANCELLED
}

struct Player {
    address addr;
    uint256 nft_id;
}

struct Speculation {
    address speculator;
    uint8 prediction; // 0 for first player, 1 for second player
    uint256 amount; // Bet amount
}

struct GameData {
    Player[2] players;
    Speculation[] speculations;
    uint256 amount;
    GameState state;
    RoundResult[] rounds;
    uint8 player1Wins;
    uint8 player2Wins;
    uint256 totalbet;
}

struct RoundResult {
    uint8 player1Roll;
    uint8 player2Roll;
    bool player1Won;
}

enum TEST_GAMETYPES {
    STANDARD,
    NO_SPECULATION,
    TWO_SPECULATIONS,
    ABORT_NO_SPECULATION,
    ABORT_WITH_SPECULATION,
    NO_APPROVAL
}
