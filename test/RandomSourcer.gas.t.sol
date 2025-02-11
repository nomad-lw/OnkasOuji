// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/RandomSourcer.sol";
import "../node_modules/@pythnetwork/entropy-sdk-solidity/EntropyStructs.sol";

contract MockRandomizer is IRandomizer {
    uint256 private request_counter;

    function request(uint256 callbackGasLimit) external returns (uint256) {
        return request_counter++;
    }

    function request(uint256 callbackGasLimit, uint256 confirmations) external returns (uint256) {
        return request_counter++;
    }

    function clientWithdrawTo(address _to, uint256 _amount) external {}

    function estimateFee(uint256 callbackGasLimit) external pure returns (uint256) {
        return 0.01 ether;
    }

    function clientBalanceOf(address _client) external pure returns (uint256 deposit, uint256 reserved) {
        return (1 ether, 0);
    }
}

contract MockPythEntropy is IEntropy {
    uint64 private sequence_counter;

    function requestRandomness(address provider, bytes32 seed) external payable returns (uint64) {
        return sequence_counter++;
    }

    function requestRandomnessFromProvider(address provider, bytes memory data) external payable returns (uint64) {
        return sequence_counter++;
    }

    function requestWithCallback(address provider, bytes32 seed) external payable returns (uint64) {
        return sequence_counter++;
    }

    function getFee(address provider) external pure returns (uint128) {
        return 0.01 ether;
    }

    function getProviderInfo(address provider) external view returns (EntropyStructs.ProviderInfo memory) {
        return EntropyStructs.ProviderInfo(
            0, // feeInWei
            0, // accruedFeesInWei
            bytes32(0), // originalCommitment
            0, // originalCommitmentSequenceNumber
            "", // commitmentMetadata
            "", // uri
            0, // endSequenceNumber
            0, // sequenceNumber
            bytes32(0), // currentCommitment
            0, // currentCommitmentSequenceNumber
            address(0) // feeManager
        );
    }

    function getRequest(address provider, uint64 sequenceNumber) external view returns (EntropyStructs.Request memory) {
        return EntropyStructs.Request(
            address(0), // provider
            0, // sequenceNumber
            0, // numHashes
            bytes32(0), // commitment
            0, // blockNumber
            address(0), // requester
            false, // useBlockhash
            false // isRequestWithCallback
        );
    }

    // Additional required function implementations with empty/dummy returns
    function register(uint128 feeInWei, bytes32 commitment, bytes calldata commitmentMetadata, uint64 chainLength, bytes calldata uri) external {}
    function withdraw(uint128 amount) external {}
    function withdrawAsFeeManager(address provider, uint128 amount) external {}

    function request(address provider, bytes32 userCommitment, bool useBlockHash) external payable returns (uint64) {
        return 0;
    }

    function reveal(address provider, uint64 sequenceNumber, bytes32 userRevelation, bytes32 providerRevelation) external returns (bytes32) {
        return bytes32(0);
    }

    function revealWithCallback(address provider, uint64 sequenceNumber, bytes32 userRandomNumber, bytes32 providerRevelation) external {}

    // function getProviderInfo(address provider) external view returns (EntropyStructs.ProviderInfo memory) {
    //     return EntropyStructs.ProviderInfo(0, 0, bytes32(0), bytes32(0), 0, "", address(0));
    // }

    function getDefaultProvider() external view returns (address) {
        return address(0);
    }

    // function getRequest(address provider, uint64 sequenceNumber) external view returns (EntropyStructs.Request memory) {
    //     return EntropyStructs.Request(address(0), bytes32(0), false, false);
    // }

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

contract RandomSourcerGasTest is Test {
    RandomSourcer private random_sourcer;
    MockRandomizer private mock_randomizer;
    MockPythEntropy private mock_pyth_entropy;

    address private constant MOCK_PYTH_PROVIDER = address(0x1);
    uint256 private constant TEST_REQ_ID = 1;
    bytes32 private constant TEST_ALPHA = bytes32("test_alpha");

    // Events for testing
    event RandomnessRequested(uint256 indexed req_id, uint8 indexed flag);
    event RandomnessGenerated(uint256 indexed req_id, uint8 indexed flag);
    event RequestCompleted(uint256 indexed req_id);

    function setUp() public {
        mock_randomizer = new MockRandomizer();
        mock_pyth_entropy = new MockPythEntropy();

        // Create contract with all sources enabled
        random_sourcer = new RandomSourcer(
            0x07, // Enable all sources (PYTH | RANDOMIZER | SAV)
            MOCK_PYTH_PROVIDER,
            address(mock_pyth_entropy),
            address(mock_randomizer)
        );
    }

    function test_gas_calc_fee() public view {
        random_sourcer.calc_fee();
    }

    function test_gas_request_random() public {
        uint256 required_fee = random_sourcer.calc_fee();
        vm.deal(address(this), required_fee);

        random_sourcer._request_random{value: required_fee}(TEST_REQ_ID, TEST_ALPHA);
    }

    function test_gas_pyth_callback() public {
        uint256 required_fee = random_sourcer.calc_fee();
        vm.deal(address(this), required_fee);

        // First make a request
        random_sourcer._request_random{value: required_fee}(TEST_REQ_ID, TEST_ALPHA);

        // Then test callback gas
        vm.prank(address(mock_pyth_entropy));
        // Call the internal _entropyCallback function
        RandomSourcer(random_sourcer)._entropyCallback(0, MOCK_PYTH_PROVIDER, bytes32("random_result"));
    }

    function test_gas_randomizer_callback() public {
        uint256 required_fee = random_sourcer.calc_fee();
        vm.deal(address(this), required_fee);

        // First make a request
        random_sourcer._request_random{value: required_fee}(TEST_REQ_ID, TEST_ALPHA);

        // Then test callback gas
        vm.prank(address(mock_randomizer));
        random_sourcer.randomizerCallback(0, bytes32("random_result"));
    }

    function test_gas_sav_callback() public {
        uint256 required_fee = random_sourcer.calc_fee();
        vm.deal(address(this), required_fee);

        // First make a request
        random_sourcer._request_random{value: required_fee}(TEST_REQ_ID, TEST_ALPHA);

        // Then test callback gas
        random_sourcer.sav_callback(TEST_REQ_ID, bytes32("random_result"));
    }

    function test_gas_get_request_status() public view {
        random_sourcer.get_request_status(TEST_REQ_ID);
    }

    function test_gas_get_active_sources() public view {
        random_sourcer.get_active_sources();
    }

    function test_gas_set_sources() public {
        random_sourcer.set_sources(0x07); // Enable all sources
    }

    function test_gas_randomizer_withdraw() public {
        random_sourcer.randomizerWithdraw(1 ether);
    }

    // Helper function to receive ETH
    receive() external payable {}
}

contract RandomSourcerFuzzTest is Test {
    RandomSourcer private random_sourcer;
    MockRandomizer private mock_randomizer;
    MockPythEntropy private mock_pyth_entropy;

    address private constant MOCK_PYTH_PROVIDER = address(0x1);

    event RandomnessRequested(uint256 indexed req_id, uint8 indexed flag);
    event RandomnessGenerated(uint256 indexed req_id, uint8 indexed flag);
    event RequestCompleted(uint256 indexed req_id);

    function setUp() public {
        mock_randomizer = new MockRandomizer();
        mock_pyth_entropy = new MockPythEntropy();

        random_sourcer = new RandomSourcer(0x07, MOCK_PYTH_PROVIDER, address(mock_pyth_entropy), address(mock_randomizer));
    }

    function testFuzz_request_random(uint256 req_id, bytes32 alpha, uint256 extra_fee) public {
        // Assumptions to make test meaningful
        vm.assume(req_id != 0); // req_id cannot be 0
        extra_fee = bound(extra_fee, 0, 1 ether); // reasonable extra fee range

        uint256 required_fee = random_sourcer.calc_fee();
        vm.deal(address(this), required_fee + extra_fee);

        random_sourcer._request_random{value: required_fee + extra_fee}(req_id, alpha);
    }

    function testFuzz_callbacks(uint256 req_id, bytes32 alpha, bytes32 random_result, uint64 sequence_number) public {
        // Assumptions
        vm.assume(req_id != 0);
        vm.assume(sequence_number != 0);

        // Setup
        uint256 required_fee = random_sourcer.calc_fee();
        vm.deal(address(this), required_fee);
        random_sourcer._request_random{value: required_fee}(req_id, alpha);

        // Test Pyth callback
        vm.prank(address(mock_pyth_entropy));
        RandomSourcer(random_sourcer)._entropyCallback(sequence_number, MOCK_PYTH_PROVIDER, random_result);

        // Test Randomizer callback
        vm.prank(address(mock_randomizer));
        random_sourcer.randomizerCallback(sequence_number, random_result);

        // Test SAV callback
        random_sourcer.sav_callback(req_id, random_result);
    }

    function testFuzz_set_sources(uint8 sources) public {
        // Only allow valid source combinations (0-7 since we have 3 sources)
        sources = uint8(bound(uint256(sources), 0, 7));
        random_sourcer.set_sources(sources);

        // Verify the sources were set correctly
        assertEq(random_sourcer.get_active_sources(), sources);
    }

    function testFuzz_randomizer_withdraw(uint256 amount) public {
        // Bound the withdrawal amount to reasonable ranges
        amount = bound(amount, 0, 1000 ether);
        random_sourcer.randomizerWithdraw(amount);
    }

    // function testFuzz_multiple_requests(uint256[5] calldata req_ids, bytes32[5] calldata alphas, uint256[5] calldata extra_fees) public {
    //     uint256 total_fee = 0;
    //     uint256 base_fee = random_sourcer.calc_fee();

    //     // Keep track of used request IDs
    //     mapping(uint256 => bool) memory used_req_ids;

    //     // Process each request
    //     for (uint256 i = 0; i < 5; i++) {
    //         // Generate a unique request ID by combining the input with the index
    //         uint256 unique_req_id = uint256(keccak256(abi.encodePacked(req_ids[i], i)));

    //         // Ensure req_id is not 0 and not used before
    //         if (unique_req_id == 0 || used_req_ids[unique_req_id]) continue;
    //         used_req_ids[unique_req_id] = true;

    //         // Bound extra fee for this request
    //         uint256 bounded_extra_fee = bound(extra_fees[i], 0, 0.1 ether);
    //         total_fee += base_fee + bounded_extra_fee;

    //         // Make sure we have enough ETH
    //         vm.deal(address(this), total_fee);

    //         // Make the request
    //         random_sourcer._request_random{value: base_fee + bounded_extra_fee}(unique_req_id, alphas[i]);
    //     }
    // }

    // function testFuzz_request_and_callback_sequence(uint256[3] calldata req_ids, bytes32[3] calldata random_results) public {
    //     uint256 base_fee = random_sourcer.calc_fee();
    //     vm.deal(address(this), base_fee * 3);

    //     // Keep track of used request IDs
    //     mapping(uint256 => bool) memory used_req_ids;

    //     // Make requests
    //     for (uint256 i = 0; i < 3; i++) {
    //         // Generate a unique request ID by combining the input with the index
    //         uint256 unique_req_id = uint256(keccak256(abi.encodePacked(req_ids[i], i)));

    //         // Ensure req_id is not 0 and not used before
    //         if (unique_req_id == 0 || used_req_ids[unique_req_id]) continue;
    //         used_req_ids[unique_req_id] = true;

    //         random_sourcer._request_random{value: base_fee}(unique_req_id, bytes32(i));

    //         // Random callbacks in different orders
    //         if (i % 3 == 0) {
    //             vm.prank(address(mock_pyth_entropy));
    //             RandomSourcer(random_sourcer)._entropyCallback(uint64(i), MOCK_PYTH_PROVIDER, random_results[i]);
    //         } else if (i % 3 == 1) {
    //             vm.prank(address(mock_randomizer));
    //             random_sourcer.randomizerCallback(i, random_results[i]);
    //         } else {
    //             random_sourcer.sav_callback(unique_req_id, random_results[i]);
    //         }
    //     }
    // }

    receive() external payable {}
}
