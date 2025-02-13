pragma solidity ^0.8.26;

import {IEntropy} from "@pythnetwork/entropy-sdk-solidity/IEntropy.sol";
import {IEntropyConsumer} from "@pythnetwork/entropy-sdk-solidity/IEntropyConsumer.sol";

// interface IEntropy {
//     function getFee(address provider) external view returns (uint128);
//     function request(address provider, bytes32 userRandomNumber) external payable returns (uint64);
//     function requestWithCallback(address provider, bytes32 userRandomNumber) external payable returns (uint64);
// }

// interface IEntropyConsumer {
//     function entropyCallback(uint64 sequenceNumber, address provider, bytes32 randomNumber) external;
// }

contract MockPythEntropy is IEntropy {
    uint64 private sequence_number = 1;
    uint128 private constant ENTROPY_FEE = 0.01 ether;

    function getFee(address provider) external pure returns (uint128) {
        return ENTROPY_FEE;
    }

    function request(address provider, bytes32 userRandomNumber) external payable returns (uint64) {
        return sequence_number++;
    }

    function requestWithCallback(address provider, bytes32 userRandomNumber) external payable returns (uint64) {
        return sequence_number++;
    }

    function triggerCallback(uint64 _sequence_number, address provider, bytes32 random_number) external {
        IEntropyConsumer(msg.sender)._entropyCallback(_sequence_number, provider, random_number);
    }
}
