pragma solidity ^0.8.26;

interface IEntropy {
    function getFee(address provider) external view returns (uint128);
    function request(address provider, bytes32 userRandomNumber) external payable returns (uint64);
    function requestWithCallback(address provider, bytes32 userRandomNumber) external payable returns (uint64);
}

interface IEntropyConsumer {
    function entropyCallback(uint64 sequenceNumber, address provider, bytes32 randomNumber) external;
}

contract MockEntropy is IEntropy {
    uint64 private sequence_number = 1;

    function getFee(address provider) external pure returns (uint128) {
        return 0.1 ether;
    }

    function request(address provider, bytes32 userRandomNumber) external payable returns (uint64) {
        return sequence_number++;
    }

    function requestWithCallback(address provider, bytes32 userRandomNumber) external payable returns (uint64) {
        return sequence_number++;
    }

    function triggerCallback(uint64 _sequence_number, address provider, bytes32 random_number) external {
        IEntropyConsumer(msg.sender).entropyCallback(_sequence_number, provider, random_number);
    }
}
