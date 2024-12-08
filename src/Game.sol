// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Game is AccessControl, Ownable {
    bytes32 public constant ROLE_OPERATOR = keccak256("OPERATOR_ROLE");

    error InvalidNFTOwnership(address player, uint256 nft_id);
    error InsufficientBalance(uint256 balance, uint256 required, address addr);

    enum GameState {
        OPEN,
        COMPLETED,
        CANCELLED
    }

    struct Player {
        address player_address;
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
    }

    // Storage
    mapping(uint256 => GameData) public games;
    uint256 private _current_game_id;
    IERC721 public NFT_CONTRACT;
    IERC20 public TOKEN_CONTRACT;

    // Events
    event GameCreated(uint256 indexed game_id, Player[2] players, uint256 amounty);

    constructor(address _nft_contract, address _token_contract) Ownable(msg.sender) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ROLE_OPERATOR, msg.sender);
        NFT_CONTRACT = IERC721(_nft_contract);
        TOKEN_CONTRACT = IERC20(_token_contract);
    }

    function new_game(Player[2] memory players, uint256 amount)
        external
        only_operator_or_owner
        returns (uint256 game_id)
    {
        // Validate
        require(
            NFT_CONTRACT.ownerOf(players[0].nft_id) == players[0].player_address
                && NFT_CONTRACT.ownerOf(players[1].nft_id) == players[1].player_address,
            "Game: Players must own their specified NFTs"
        );

        // Validate bets are valid (0 or 1)
        // for (uint256 i = 0; i < bets.length; i++) {
        //     require(bets[i] <= 1, "Game: Invalid bet value");
        // }

        // Increment game ID
        _current_game_id++;
        game_id = _current_game_id;

        // Create new game
        GameData storage new_game = games[game_id];

        // Set player info
        new_game.players[0] = PlayerInfo(player_addresses[0], nft_ids[0]);
        new_game.players[1] = PlayerInfo(player_addresses[1], nft_ids[1]);

        // Set speculators and bets
        new_game.speculators = speculators;
        new_game.bets = bets;
        new_game.state = GameState.OPEN;
        new_game.timestamp = block.timestamp;

        emit GameCreated(game_id, new_game.players, speculators, bets, block.timestamp);
    }

    function get_current_game_id() external view returns (uint256) {
        return _current_game_id;
    }

    function get_game(uint256 game_id) external view returns (GameData memory) {
        require(game_id > 0 && game_id <= _current_game_id, "Game: Invalid game ID");
        return games[game_id];
    }

    function get_speculator_bets(uint256 game_id) external view returns (SpeculatorBet[] memory) {
        require(game_id > 0 && game_id <= _current_game_id, "Game: Invalid game ID");
        GameData storage game = games[game_id];

        SpeculatorBet[] memory speculator_bets = new SpeculatorBet[](game.speculators.length);
        for (uint256 i = 0; i < game.speculators.length; i++) {
            speculator_bets[i] = SpeculatorBet(game.speculators[i], game.bets[i]);
        }

        return speculator_bets;
    }

    modifier only_operator_or_owner() {
        require(hasRole(ROLE_OPERATOR, msg.sender) || owner() == msg.sender, "Game: Caller is not an operator or owner");
        _;
    }
}
