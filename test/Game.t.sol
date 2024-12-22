// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import {OnkasOujiGame, GameData, GameState, Player, Speculation, RoundResult, IEntropy} from "../src/OnkasOujiGame.sol";
import "../src/lib/models.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {EntropyStructs} from "node_modules/@pythnetwork/entropy-sdk-solidity/EntropyStructs.sol";

// Mock contracts

event UserRegistered(bytes32 indexed secret, address indexed addr);

contract MockNFT is ERC721 {
    constructor() ERC721("MockOnkasOujiNFT", "ONKAS") {}

    function mint(address to, uint256 tokenId) public {
        _mint(to, tokenId);
    }
}

contract MockGOLD is ERC20 {
    constructor() ERC20("MockGOLD", "GOLD") {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract MockEntropy is IEntropy {
    uint64 private sequenceNumber = 1;
    mapping(address => uint128) private fees;

    function getFee(address) external pure returns (uint128) {
        return 0.01 ether;
    }

    function requestWithCallback(address, bytes32) external payable returns (uint64) {
        return sequenceNumber++;
    }

    function register(uint128 feeInWei, bytes32 commitment, bytes calldata commitmentMetadata, uint64 chainLength, bytes calldata uri) external {}

    function withdraw(uint128 amount) external {}

    function withdrawAsFeeManager(address provider, uint128 amount) external {}

    function request(address provider, bytes32 userCommitment, bool useBlockHash) external payable returns (uint64) {
        return sequenceNumber++;
    }

    function reveal(address provider, uint64 sequenceNumber, bytes32 userRevelation, bytes32 providerRevelation) external returns (bytes32) {
        return bytes32(0);
    }

    function revealWithCallback(address provider, uint64 sequenceNumber, bytes32 userRandomNumber, bytes32 providerRevelation) external {}

    function getProviderInfo(address provider) external view returns (EntropyStructs.ProviderInfo memory) {
        return EntropyStructs.ProviderInfo({
            feeInWei: 0,
            accruedFeesInWei: 0,
            originalCommitment: bytes32(0),
            originalCommitmentSequenceNumber: 0,
            commitmentMetadata: new bytes(0),
            uri: new bytes(0),
            endSequenceNumber: 0,
            sequenceNumber: 0,
            currentCommitment: bytes32(0),
            currentCommitmentSequenceNumber: 0,
            feeManager: address(0)
        });
    }

    function getRequest(address provider, uint64 sequenceNumber) external view returns (EntropyStructs.Request memory) {
        return EntropyStructs.Request({
            provider: address(0),
            sequenceNumber: 0,
            numHashes: 0,
            commitment: bytes32(0),
            blockNumber: 0,
            requester: address(0),
            useBlockhash: false,
            isRequestWithCallback: false
        });
    }

    function getDefaultProvider() external view returns (address) {
        return address(this);
    }

    function getAccruedPythFees() external view returns (uint128) {
        return 0;
    }

    function setProviderFee(uint128 newFeeInWei) external {}

    function setProviderFeeAsFeeManager(address provider, uint128 newFeeInWei) external {}

    function setProviderUri(bytes calldata newUri) external {}

    function setFeeManager(address manager) external {}

    function constructUserCommitment(bytes32 userRandomness) external pure returns (bytes32) {
        return bytes32(0);
    }

    function combineRandomValues(bytes32 userRandomness, bytes32 providerRandomness, bytes32 blockHash) external pure returns (bytes32) {
        return bytes32(0);
    }
}

contract GameTest is Test {
    OnkasOujiGame public game;
    MockNFT public nft;
    MockGOLD public token;
    MockEntropy public entropy;

    address public owner;
    address public player1;
    address public player2;
    address public speculator;
    address public operator;

    function setUp() public {
        owner = address(this);
        player1 = address(0x1);
        player2 = address(0x2);
        speculator = address(0x3);
        operator = address(0x4);

        // Deploy mock contracts
        nft = new MockNFT();
        token = new MockGOLD();
        entropy = new MockEntropy();

        // Deploy game contract
        game = new OnkasOujiGame(
            address(nft),
            address(token),
            address(entropy),
            address(entropy), // Using same address for provider
            operator
        );

        // Setup initial state
        vm.deal(owner, 100 ether);
        vm.deal(player1, 100 ether);
        vm.deal(player2, 100 ether);
        vm.deal(speculator, 100 ether);

        // Mint NFTs
        nft.mint(player1, 1);
        nft.mint(player2, 2);

        // Mint tokens
        token.mint(player1, 1000 ether);
        token.mint(player2, 1000 ether);
        token.mint(speculator, 1000 ether);

        // Approve token spending
        vm.prank(player1);
        token.approve(address(game), type(uint256).max);
        vm.prank(player2);
        token.approve(address(game), type(uint256).max);
        vm.prank(speculator);
        token.approve(address(game), type(uint256).max);
    }

    function testRegisterSuccess() public {
        // Create a random secret
        bytes32 secret = keccak256(abi.encodePacked("some random secret"));

        // Switch to user context
        vm.startPrank(player1);

        // Expect the UserRegistered event to be emitted
        vm.expectEmit(true, true, false, true);
        emit UserRegistered(secret, player1);

        // Call register
        game.register(secret);

        // Verify token approval
        assertEq(token.allowance(player1, address(game)), type(uint256).max, "Token allowance should be set to max");

        vm.stopPrank();
    }

    function test_NewGame() public {
        Player[2] memory players = [Player(player1, 1), Player(player2, 2)];

        uint256 gameId = game.new_game(players, 1 ether);

        assertEq(gameId, 1);

        GameData memory gameData = game.get_game(gameId);
        assertEq(gameData.players[0].addr, player1);
        assertEq(gameData.players[1].addr, player2);
        assertEq(gameData.amount, 1 ether);
        assertEq(uint8(gameData.state), uint8(GameState.OPEN));
    }

    function test_AddSpeculation() public {
        // First create a game
        Player[2] memory players = [Player(player1, 1), Player(player2, 2)];
        uint256 gameId = game.new_game(players, 1 ether);

        // Add speculation
        game.place_bet(gameId, speculator, 0, 0.5 ether);

        Speculation[] memory speculations = game.get_speculations(gameId);
        assertEq(speculations.length, 1);
        assertEq(speculations[0].speculator, speculator);
        assertEq(speculations[0].prediction, 0);
        assertEq(speculations[0].amount, 0.5 ether);
    }

    function test_StartGame() public {
        Player[2] memory players = [Player(player1, 1), Player(player2, 2)];
        uint256 gameId = game.new_game(players, 1 ether);

        game.start_game{value: 0.01 ether}(gameId);

        // Note: We can't test the full game completion here as it depends on the entropy callback
    }

    function test_AbortGame() public {
        Player[2] memory players = [Player(player1, 1), Player(player2, 2)];
        uint256 gameId = game.new_game(players, 1 ether);

        uint256 player1BalanceBefore = token.balanceOf(player1);
        uint256 player2BalanceBefore = token.balanceOf(player2);

        game.abort_game(gameId);

        GameData memory gameData = game.get_game(gameId);
        assertEq(uint8(gameData.state), uint8(GameState.CANCELLED));

        assertEq(token.balanceOf(player1), player1BalanceBefore + 1 ether);
        assertEq(token.balanceOf(player2), player2BalanceBefore + 1 ether);
    }

    function testFail_InvalidNFTOwnership() public {
        Player[2] memory players = [
            Player(address(0x4), 1), // Invalid owner
            Player(player2, 2)
        ];

        game.new_game(players, 1 ether);
    }

    function testFail_InvalidGameId() public {
        game.get_game(999); // Non-existent game ID
    }

    function testFail_InsufficientBalance() public {
        Player[2] memory players = [Player(player1, 1), Player(player2, 2)];

        game.new_game(players, 2000 ether); // More than minted amount
    }

    function test_GetCurrentGameId() public {
        Player[2] memory players = [Player(player1, 1), Player(player2, 2)];

        game.new_game(players, 1 ether);
        game.new_game(players, 1 ether);

        assertEq(game.get_current_game_id(), 2);
    }

    function test_EntropyCallback() public {
        // Setup game
        Player[2] memory players = [Player(player1, 1), Player(player2, 2)];
        uint256 gameId = game.new_game(players, 1 ether);

        // Add some speculations
        game.place_bet(gameId, speculator, 0, 0.5 ether);

        // Start game
        game.start_game{value: 0.01 ether}(gameId);

        // Get initial balances
        uint256 player1BalanceBefore = token.balanceOf(player1);
        uint256 player2BalanceBefore = token.balanceOf(player2);
        uint256 speculatorBalanceBefore = token.balanceOf(speculator);

        // Simulate entropy callback
        vm.prank(address(entropy));
        game._entropyCallback(1, address(entropy), bytes32(uint256(1))); // Using a deterministic random number

        // Get game data after completion
        GameData memory gameData = game.get_game(gameId);

        // Verify game state
        assertEq(uint8(gameData.state), uint8(GameState.COMPLETED));

        // Check winner payouts (exact amounts will depend on who won)
        if (gameData.player1Wins > gameData.player2Wins) {
            assertEq(token.balanceOf(player1), player1BalanceBefore + 2 ether);
            assertEq(token.balanceOf(player2), player2BalanceBefore);
        } else {
            assertEq(token.balanceOf(player1), player1BalanceBefore);
            assertEq(token.balanceOf(player2), player2BalanceBefore + 2 ether);
        }

        // Check speculator payouts
        // This will need to be adjusted based on the actual game outcome
        // and the speculator's prediction
    }

    function test_CompleteGameFlow() public {
        // Setup game
        Player[2] memory players = [Player(player1, 1), Player(player2, 2)];

        // Record initial balances
        uint256 player1InitialBalance = token.balanceOf(player1);
        uint256 player2InitialBalance = token.balanceOf(player2);

        // Create game with 1 ETH stake
        uint256 gameId = game.new_game(players, 1 ether);

        // Verify stake was taken
        assertEq(token.balanceOf(player1), player1InitialBalance - 1 ether);
        assertEq(token.balanceOf(player2), player2InitialBalance - 1 ether);

        // Add speculations
        game.place_bet(gameId, speculator, 0, 0.5 ether); // betting on player1
        uint256 speculatorInitialBalance = token.balanceOf(speculator);

        // Start game
        game.start_game{value: 0.01 ether}(gameId);

        // Simulate entropy callback with a predetermined random number that will make player1 win
        // This random number will generate specific dice rolls through the keccak256 hashing
        bytes32 mockRandomNumber = bytes32(uint256(1234)); // Using a specific seed

        vm.prank(address(entropy));
        game._entropyCallback(1, address(entropy), mockRandomNumber);

        // Get final game state
        GameData memory gameData = game.get_game(gameId);

        // Verify game completed
        assertEq(uint8(gameData.state), uint8(GameState.COMPLETED));

        // Get final balances
        uint256 player1FinalBalance = token.balanceOf(player1);
        uint256 player2FinalBalance = token.balanceOf(player2);
        uint256 speculatorFinalBalance = token.balanceOf(speculator);

        // Check winner and payouts
        if (gameData.player1Wins > gameData.player2Wins) {
            // Player 1 won
            assertEq(player1FinalBalance, player1InitialBalance + 1 ether); // Gets original stake + winnings
            assertEq(player2FinalBalance, player2InitialBalance - 1 ether); // Lost stake
                // assertEq(speculatorFinalBalance, speculatorInitialBalance + 0.5 ether); // Won bet
        } else {
            // Player 2 won
            assertEq(player1FinalBalance, player1InitialBalance - 1 ether); // Lost stake
            assertEq(player2FinalBalance, player2InitialBalance + 1 ether); // Gets original stake + winnings
                // assertEq(speculatorFinalBalance, speculatorInitialBalance - 0.5 ether); // Lost bet
        }

        // Verify round results were recorded
        assertGt(gameData.rounds.length, 0);

        // Test that we can't callback twice
        vm.expectRevert();
        vm.prank(address(entropy));
        game._entropyCallback(1, address(entropy), mockRandomNumber);
    }

    function testFail_InvalidEntropyProvider() public {
        Player[2] memory players = [Player(player1, 1), Player(player2, 2)];
        uint256 gameId = game.new_game(players, 1 ether);
        game.start_game{value: 0.01 ether}(gameId);

        // Try to callback from wrong provider
        vm.prank(address(0x1234));
        game._entropyCallback(1, address(0x1234), bytes32(0));
    }

    function test_MultipleGamesWithEntropy() public {
        Player[2] memory players = [Player(player1, 1), Player(player2, 2)];

        // Create and complete multiple games
        for (uint64 i = 0; i < 3; i++) {
            uint256 gameId = game.new_game(players, 1 ether);
            game.start_game{value: 0.01 ether}(gameId);

            vm.prank(address(entropy));
            game._entropyCallback(i + 1, address(entropy), bytes32(uint256(1234 + i)));

            GameData memory gameData = game.get_game(gameId);
            assertEq(uint8(gameData.state), uint8(GameState.COMPLETED));
        }
    }
}
