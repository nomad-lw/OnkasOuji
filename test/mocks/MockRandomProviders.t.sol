// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {Wyrd} from "src/Wyrd.sol";
import {IEntropy} from "@pythnetwork/entropy-sdk-solidity/IEntropy.sol";
import {IEntropyConsumer} from "node_modules/@pythnetwork/entropy-sdk-solidity/IEntropyConsumer.sol";
import {IRandomizer} from "src/interfaces/ext/IRandomizer.sol";
import {VRF} from "vrf-solidity/contracts/VRF.sol";
import {EntropyStructs} from "@pythnetwork/entropy-sdk-solidity/EntropyStructs.sol";
import {ADDR_PYTH_PROVIDER} from "test/config.sol";

contract MockPythEntropy is IEntropy {
    mapping(address => mapping(uint64 => EntropyStructs.Request)) public requests;
    mapping(address => uint64) internal _providerSequenceNumbers;
    mapping(address => mapping(uint64 => bytes32)) internal _providerResponses;

    uint128 private constant MOCK_FEE = 0.01 ether;

    function getFee(address) external pure returns (uint128) {
        return MOCK_FEE;
    }

    function getRequest(address provider, uint64 sequence_number) external view returns (EntropyStructs.Request memory) {
        return requests[provider][sequence_number];
    }

    function getLatestSequenceNumber(address provider) external view returns (uint64 idx) {
        idx = _providerSequenceNumbers[provider];
    }

    function requestWithCallback(address provider, bytes32 user_random_number) external payable returns (uint64) {
        require(msg.value >= MOCK_FEE, "Insufficient fee");
        require(provider == ADDR_PYTH_PROVIDER, "Invalid provider");

        _providerSequenceNumbers[provider]++;
        uint64 sequenceNumber = _providerSequenceNumbers[provider];

        _providerResponses[provider][sequenceNumber] = keccak256(abi.encodePacked("entropy", sequenceNumber));

        // Create a new request
        EntropyStructs.Request memory req;
        req.requester = msg.sender;
        req.provider = provider;
        req.sequenceNumber = sequenceNumber;
        req.commitment = keccak256(abi.encodePacked(user_random_number, _providerResponses[provider][sequenceNumber]));
        req.isRequestWithCallback = true;
        // Store the request
        requests[provider][sequenceNumber] = req;

        return sequenceNumber;
    }

    function triggerCallback(uint64 sequenceNumber) external {
        require(msg.sender == ADDR_PYTH_PROVIDER, "Invalid prover");
        if (_providerResponses[msg.sender][sequenceNumber] == 0) {
            _providerResponses[msg.sender][sequenceNumber] = keccak256(abi.encodePacked("entropy", sequenceNumber));
        }
        EntropyStructs.Request memory req = requests[msg.sender][sequenceNumber];
        IEntropyConsumer(req.requester)._entropyCallback(req.sequenceNumber, msg.sender, _providerResponses[msg.sender][sequenceNumber]);
    }

    // Implement other required interface methods with empty implementations
    function register(uint128, bytes32, bytes calldata, uint64, bytes calldata) external {}

    function withdraw(uint128) external {}

    function withdrawAsFeeManager(address, uint128) external {}

    function request(address, bytes32, bool) external payable returns (uint64) {
        return 0;
    }

    function reveal(address, uint64, bytes32, bytes32) external pure returns (bytes32) {
        return bytes32(0);
    }

    function revealWithCallback(address, uint64, bytes32, bytes32) external {}

    function getProviderInfo(address) external pure returns (EntropyStructs.ProviderInfo memory) {
        EntropyStructs.ProviderInfo memory info;
        return info;
    }

    function getDefaultProvider() external pure returns (address) {
        return ADDR_PYTH_PROVIDER;
    }

    function getAccruedPythFees() external pure returns (uint128) {
        return 0;
    }

    function setProviderFee(uint128) external {}

    function setProviderFeeAsFeeManager(address, uint128) external {}

    function setProviderUri(bytes calldata) external {}

    function setFeeManager(address) external {}

    function constructUserCommitment(bytes32 userRandomness) external pure returns (bytes32) {
        return keccak256(abi.encodePacked(userRandomness));
    }

    function combineRandomValues(bytes32 userRandomness, bytes32 providerRandomness, bytes32 blockHash) external pure returns (bytes32) {
        return keccak256(abi.encodePacked(userRandomness, providerRandomness, blockHash));
    }
}

contract MockRandomizer is IRandomizer {
    uint256 private constant MOCK_FEE = 0.01 ether;
    mapping(address => uint256) public deposits;
    mapping(address => uint256) public reserved;
    mapping(uint256 => bytes32) public results;

    function estimateFee(uint256) external pure returns (uint256) {
        return MOCK_FEE;
    }

    function getFeeStats(uint256) external pure returns (uint256[2] memory) {
        uint256[2] memory stats;
        stats[0] = MOCK_FEE;
        return stats;
    }

    function clientBalanceOf(address _client) external view returns (uint256 deposit, uint256 reserved_amount) {
        return (deposits[_client], reserved[_client]);
    }

    function getRequest(uint256 request_id)
        external
        view
        returns (bytes32 result, bytes32 dataHash, uint256 ethPaid, uint256 ethRefunded, bytes10[2] memory vrfHashes)
    {
        result = results[request_id];
        ethPaid = MOCK_FEE;
        return (result, dataHash, ethPaid, ethRefunded, vrfHashes);
    }

    function request(uint256) external returns (uint256) {
        uint256 request_id = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender)));
        results[request_id] = keccak256(abi.encodePacked("randomizer", request_id));
        return request_id;
    }

    function clientDeposit(address client) external payable {
        deposits[client] += msg.value;
    }

    function clientWithdrawTo(address to, uint256 amount) external {
        address client = msg.sender;
        require(deposits[client] >= amount, "Insufficient balance");
        deposits[client] -= amount;
        (bool success,) = to.call{value: amount}("");
        require(success, "Transfer failed");
    }
}
