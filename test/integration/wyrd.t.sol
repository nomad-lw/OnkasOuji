// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {Wyrd} from "src/Wyrd.sol";
import "test/config.sol" as cfg;
import {VRFTestData} from "test/utils/VRFTestData.sol";

import {MockPythEntropy} from "test/mocks/MockRandomProviders.t.sol";
import {MockRandomizer} from "test/mocks/MockRandomProviders.t.sol";
import {IEntropy} from "@pythnetwork/entropy-sdk-solidity/IEntropy.sol";
import {IRandomizer} from "src/interfaces/ext/IRandomizer.sol";

contract TestableWyrd is Wyrd {
    constructor(uint8 _flags, address _pyth_provider, address _pyth_entropy, address _randomizer, uint256[2] memory _sav_pk, bool _store_alpha)
        Wyrd(_flags, _pyth_provider, _pyth_entropy, _randomizer, _sav_pk, _store_alpha)
    {}

    function request_random(uint256 req_id, bytes32 alpha) external payable {
        _request_random(req_id, alpha);
    }

    // Expose internal variables for testing
    function get_role_operator() external pure returns (uint256) {
        return ROLE_OPERATOR;
    }

    function get_role_sav_prover() external pure returns (uint256) {
        return ROLE_SAV_PROVER;
    }

    function get_store_alpha_inputs() external view returns (bool) {
        return STORE_ALPHA_INPUTS;
    }
}

contract WyrdTests is Test {
    TestableWyrd wyrd;
    uint8 expected_source_flags;

    // Mock providers
    MockPythEntropy mock_pyth_entropy;
    MockRandomizer mock_randomizer;

    // Role flags
    uint256 role_operator;
    uint256 role_sav_prover;

    // a nominal behaviour test
    function setUp() public {
        // Deploy mock providers
        mock_pyth_entropy = new MockPythEntropy();
        mock_randomizer = new MockRandomizer();

        // Prank as deployer and create Wyrd with mock providers
        vm.prank(cfg.ADDR_DEPLOYER);
        wyrd = new TestableWyrd(
            cfg.FLAG_ALL_SOURCES,
            cfg.ADDR_PYTH_PROVIDER,
            address(mock_pyth_entropy),
            address(mock_randomizer),
            [cfg.SAV_PROVER_PK_X, cfg.SAV_PROVER_PK_Y],
            true
        );

        role_operator = wyrd.get_role_operator();
        role_sav_prover = wyrd.get_role_sav_prover();

        expected_source_flags = cfg.FLAG_ALL_SOURCES;

        // Fund address with ETH for tests
        vm.deal(cfg.ADDR_DEPLOYER, 10 ether);
        vm.deal(cfg.ADDR_OPERATOR, 10 ether);
        vm.deal(cfg.ADDR_SAV_PROVER, 10 ether);
        vm.deal(address(this), 10 ether);
    }

    function test_user_role_management() public {
        // Test ownership
        console.log("Deployer:", cfg.ADDR_DEPLOYER);
        assertEq(wyrd.owner(), cfg.ADDR_DEPLOYER);

        // Get role constants from contract
        // uint256 role_operator = wyrd.get_role_operator();
        // uint256 role_sav_prover = wyrd.get_role_sav_prover();

        // Check deployer has all expected roles
        vm.startPrank(cfg.ADDR_DEPLOYER);

        // Test deployer has operator role
        console.log("Testing deployer has ROLE_OPERATOR");
        assertTrue(wyrd.hasAnyRole(cfg.ADDR_DEPLOYER, role_operator), "Deployer should have operator role");

        // Test deployer has SAV prover role
        console.log("Testing deployer has ROLE_SAV_PROVER");
        assertTrue(wyrd.hasAnyRole(cfg.ADDR_DEPLOYER, role_sav_prover), "Deployer should have SAV prover role");

        // Grant operator role to ADDR_OPERATOR
        console.log("Granting ROLE_OPERATOR to ADDR_OPERATOR");
        wyrd.grantRoles(cfg.ADDR_OPERATOR, role_operator);

        // Grant SAV_PROVER role to ADDR_SAV_PROVER
        console.log("Granting ROLE_SAV_PROVER to ADDR_SAV_PROVER");
        wyrd.grantRoles(cfg.ADDR_SAV_PROVER, role_sav_prover);

        // Verify roles were granted correctly
        assertTrue(wyrd.hasAnyRole(cfg.ADDR_OPERATOR, role_operator), "ADDR_OPERATOR should have operator role");
        assertTrue(wyrd.hasAnyRole(cfg.ADDR_SAV_PROVER, role_sav_prover), "ADDR_SAV_PROVER should have SAV prover role");

        vm.stopPrank();
    }

    function test_provider_flags() public {
        console.log("Testing randomness source provider flags");

        // Initial test with all sources active
        uint8 sources = wyrd.get_active_sources();
        assertEq(sources, expected_source_flags);

        vm.startPrank(cfg.ADDR_DEPLOYER);

        // Test with only Pyth source active
        wyrd.set_sources(cfg.FLAG_PYTH);
        sources = wyrd.get_active_sources();
        assertEq(sources, cfg.FLAG_PYTH);

        // Test with only Randomizer source active
        wyrd.set_sources(cfg.FLAG_RANDOMIZER);
        sources = wyrd.get_active_sources();
        assertEq(sources, cfg.FLAG_RANDOMIZER);

        // Test with only SAV source active
        wyrd.set_sources(cfg.FLAG_SAV);
        sources = wyrd.get_active_sources();
        assertEq(sources, cfg.FLAG_SAV);

        // Test with Pyth and Randomizer active
        wyrd.set_sources(cfg.FLAG_PYTH | cfg.FLAG_RANDOMIZER);
        sources = wyrd.get_active_sources();
        assertEq(sources, cfg.FLAG_PYTH | cfg.FLAG_RANDOMIZER);

        // Test with Pyth and SAV active
        wyrd.set_sources(cfg.FLAG_PYTH | cfg.FLAG_SAV);
        sources = wyrd.get_active_sources();
        assertEq(sources, cfg.FLAG_PYTH | cfg.FLAG_SAV);

        // Test with Randomizer and SAV active
        wyrd.set_sources(cfg.FLAG_RANDOMIZER | cfg.FLAG_SAV);
        sources = wyrd.get_active_sources();
        assertEq(sources, cfg.FLAG_RANDOMIZER | cfg.FLAG_SAV);

        // Reset to all sources active
        wyrd.set_sources(cfg.FLAG_ALL_SOURCES);
        sources = wyrd.get_active_sources();
        assertEq(sources, cfg.FLAG_ALL_SOURCES);

        vm.stopPrank();
    }

    // function setup_for_request() public {
    //     uint256 req_id = 12345;
    //     bytes32 alpha = bytes32(uint256(0xABCDEF));
    //     (uint256 required_fee, uint128 pyth_fee, uint256 randomizer_fee) = wyrd.calc_fee();
    // }

    function test_request() public {
        uint256 req_id = 12345;
        bytes32 alpha = bytes32(uint256(0xABCDEF));
        // uint256 test_fee = 0.1 ether;

        // Calculate required fee
        (uint256 required_fee,,) = wyrd.calc_fee();

        // Ensure we have enough ETH for the test
        vm.deal(cfg.ADDR_OPERATOR, required_fee);

        // Setup event monitoring
        vm.recordLogs();

        // Give operator role permission to make the request
        vm.startPrank(cfg.ADDR_DEPLOYER);
        wyrd.grantRoles(cfg.ADDR_OPERATOR, wyrd.get_role_operator());
        vm.stopPrank();

        // Make request as operator with enough ETH to cover fees
        vm.prank(cfg.ADDR_OPERATOR);
        wyrd.request_random{value: required_fee}(req_id, alpha);

        // Get recorded logs
        Vm.Log[] memory logs = vm.getRecordedLogs();

        // Expected events count based on active sources
        uint8 sources = wyrd.get_active_sources();
        uint8 expected_event_count = 0;

        // Check for RandomnessRequested events
        if ((sources & cfg.FLAG_PYTH) != 0) expected_event_count++;
        if ((sources & cfg.FLAG_RANDOMIZER) != 0) expected_event_count++;
        if ((sources & cfg.FLAG_SAV) != 0) expected_event_count++;

        // Counter for validation
        uint8 event_count = 0;

        // Helper variables for checking provider interactions
        bool pyth_event_found = false;
        bool randomizer_event_found = false;
        bool sav_event_found = false;

        // Check event signatures and details
        bytes32 request_event_signature = keccak256("RandomnessRequested(uint256,uint8)");

        for (uint256 i = 0; i < logs.length; i++) {
            Vm.Log memory current_log = logs[i];

            // Check for RandomnessRequested events
            if (current_log.topics[0] == request_event_signature) {
                // Extract req_id and flag from event
                uint256 event_req_id = uint256(current_log.topics[1]);
                uint8 event_flag = uint8(uint256(current_log.topics[2]));

                // Validate req_id
                assertEq(event_req_id, req_id, "Event req_id doesn't match requested ID");

                // Track which sources were found
                if (event_flag == cfg.FLAG_PYTH) {
                    pyth_event_found = true;
                    event_count++;
                } else if (event_flag == cfg.FLAG_RANDOMIZER) {
                    randomizer_event_found = true;
                    event_count++;
                } else if (event_flag == cfg.FLAG_SAV) {
                    sav_event_found = true;
                    event_count++;
                }
            }
        }

        // Verify we received all expected events
        assertEq(event_count, expected_event_count, "Did not receive expected number of request events");

        // Check each source was requested correctly based on configuration
        if ((sources & cfg.FLAG_PYTH) != 0) {
            assertTrue(pyth_event_found, "Pyth request event not found but source is enabled");
            // We would check for Pyth contract interaction here if we had more detailed mocks
        }

        if ((sources & cfg.FLAG_RANDOMIZER) != 0) {
            assertTrue(randomizer_event_found, "Randomizer request event not found but source is enabled");
            // We would check for Randomizer contract interaction here if we had more detailed mocks
        }

        if ((sources & cfg.FLAG_SAV) != 0) {
            assertTrue(sav_event_found, "SAV request event not found but source is enabled");
            // No external contract interaction for SAV as it's handled internally
        }

        // Check request status
        (bool active, uint8 remaining_sources) = wyrd.get_request_status(req_id);
        assertTrue(active, "Request should be active");
        assertEq(remaining_sources, sources, "Remaining sources should match enabled sources");

        // Verify alpha was stored if STORE_ALPHA_INPUTS is true
        if (wyrd.get_store_alpha_inputs()) {
            bytes32 stored_alpha = wyrd.get_alpha(req_id);
            assertEq(stored_alpha, alpha, "Stored alpha doesn't match request alpha");
        }
    }

    function test_request_and_all_provider_callbacks() public {
        uint256 req_id = 12345;
        // bytes32 alpha = bytes32(uint256(0xABCDEF));
        // (uint256[2] , bytes memory alpha, uint256[2], uint256[4], bytes ) = VRFTestData.get_valid_vrf_proof()[1];
        (, bytes memory alpha,,,,,,,) = VRFTestData.get_valid_vrf_proof();

        // Calculate required fee
        (uint256 required_fee,,) = wyrd.calc_fee();

        // Give operator role permission to make the request
        vm.startPrank(cfg.ADDR_DEPLOYER);
        wyrd.grantRoles(cfg.ADDR_OPERATOR, role_operator);
        wyrd.grantRoles(cfg.ADDR_SAV_PROVER, role_sav_prover);
        // Restrict deployer to only owner
        wyrd.revokeRoles(cfg.ADDR_DEPLOYER, role_operator);
        wyrd.revokeRoles(cfg.ADDR_DEPLOYER, role_sav_prover);
        vm.stopPrank();

        // Make request as operator with enough ETH to cover fees
        vm.prank(cfg.ADDR_OPERATOR);
        wyrd.request_random{value: required_fee}(req_id, bytes32(alpha));

        // Verify request status before callbacks
        (bool active, uint8 remaining_sources) = wyrd.get_request_status(req_id);
        assertTrue(active, "Request should be active");

        // Get the latest sequence number from Pyth mock's internal state
        // For full tests, you might need to expose this via a getter function in the mock
        uint64 sequence_number = 1; // This would be the sequence number from the request

        // Trigger Pyth callback
        vm.prank(cfg.ADDR_PYTH_PROVIDER);
        mock_pyth_entropy.triggerCallback(sequence_number);

        // For Randomizer, the response would happen when someone calls the callback directly
        // Get the request ID from the mock (we use a dummy here since it's deterministic in your mock)
        uint256 randomizer_req_id = uint256(keccak256(abi.encodePacked(block.timestamp, address(wyrd))));
        bytes32 randomizer_result = keccak256(abi.encodePacked("randomizer", randomizer_req_id));

        // Trigger Randomizer callback
        vm.prank(address(mock_randomizer));
        wyrd.randomizerCallback(randomizer_req_id, randomizer_result);

        // For SAV, we need to generate a valid VRF proof
        // For testing, we can simulate this with a simple proof structure
        // uint256[4] memory proof;
        // uint256[2] memory U;
        // uint256[4] memory V;
        // bytes memory alpha_bytes = abi.encodePacked(alpha);
        (
            uint256[2] memory pk,
            ,
            uint256[2] memory U,
            uint256[4] memory V,
            bytes memory pi,
            bytes32 beta,
            uint256[4] memory proof,
            uint256 prebeta,
            bytes memory pub
        ) = VRFTestData.get_valid_vrf_proof();
        assertEq(uint256(beta), prebeta);
        console.log("beta:", uint256(beta));
        console.log("beta as bytes");
        console.logBytes32(beta);
        // bytes32 beta = keccak256(abi.encodePacked("sav", req_id));

        // Since we can't easily generate a valid VRF proof in the test,
        // you might need to mock or override the verification for testing

        // Trigger SAV callback (assuming the prover has the role)
        bytes memory alpha_bytes = abi.encodePacked(alpha);
        // Print alpha and alpha_bytes for debugging
        console.log("alpha:");
        console.logBytes(alpha);
        console.log("alpha_bytes:");
        console.logBytes(alpha_bytes);
        console.log("alpha as uint:", uint256(bytes32(alpha)));
        console.log("alpha_bytes length:", alpha_bytes.length);
        bytes32 alpha_as_bytes32;
        assembly {
            alpha_as_bytes32 := mload(add(alpha_bytes, 32))
        }
        console.log("alpha_bytes as uint:", uint256(alpha_as_bytes32));
        vm.startPrank(cfg.ADDR_SAV_PROVER);
        // Fast forward time and change SAV public key
        vm.warp(block.timestamp + 5 hours);
        wyrd.set_sav_public_key(pk);

        uint256[2] memory decoded_pk = VRFTestData.decodePoint(pub);
        console.log("Decoded public key:", decoded_pk[0], decoded_pk[1]);
        console.log("Provided public key:", pk[0], pk[1]);
        assertEq(decoded_pk[0], pk[0]);
        assertEq(decoded_pk[1], pk[1]);

        uint256[4] memory decoded_proof = VRFTestData.decodeProof(pi);
        console.log("Decoded proof:");
        console.log(decoded_proof[0], decoded_proof[1], decoded_proof[2], decoded_proof[3]);
        console.log("Provided proof:");
        console.log(proof[0], proof[1], proof[2], proof[3]);
        assertEq(decoded_proof[0], proof[0]);
        assertEq(decoded_proof[1], proof[1]);
        assertEq(decoded_proof[2], proof[2]);
        assertEq(decoded_proof[3], proof[3]);

        // bool local_verify = VRFTestData.verify(pk,proof,bytes.concat(bytes32(alpha)));
        bool local_verify = VRFTestData.verify(pk, proof, alpha);
        console.log("Local verification result:", local_verify);
        assertTrue(local_verify, "Local proof verification failed");

        (uint256[2] memory _U, uint256[4] memory _V) = wyrd.compute_fast_verify_params(proof, alpha_bytes);
        // Check if computed U and V match the provided values
        // Print U and computed U values for debugging
        console.log("U values:");
        console.log("Provided U[0]:", U[0]);
        console.log("Computed _U[0]:", _U[0]);
        console.log("Provided U[1]:", U[1]);
        console.log("Computed _U[1]:", _U[1]);

        // Print V and computed V values for debugging
        console.log("V values:");
        console.log("Provided V[0]:", V[0]);
        console.log("Computed _V[0]:", _V[0]);
        console.log("Provided V[1]:", V[1]);
        console.log("Computed _V[1]:", _V[1]);
        console.log("Provided V[2]:", V[2]);
        console.log("Computed _V[2]:", _V[2]);
        console.log("Provided V[3]:", V[3]);
        console.log("Computed _V[3]:", _V[3]);
        assertTrue(U[0] == _U[0] && U[1] == _U[1], "U values should match");
        assertTrue(V[0] == _V[0] && V[1] == _V[1] && V[2] == _V[2] && V[3] == _V[3], "V values should match");

        wyrd.sav_callback(req_id, alpha_bytes, beta, proof, U, V);
        vm.stopPrank();

        // Check if request is completed
        (active, remaining_sources) = wyrd.get_request_status(req_id);
        assertFalse(active, "Request should be completed after all callbacks");

        // Verify random value is available
        (bytes32 rand, bool completed) = wyrd.get_random_value(req_id);
        assertTrue(completed, "Random value generation should be marked as completed");
        assertNotEq(rand, bytes32(0), "Random value should not be zero");
    }

    function test_a_rediculously_long_fn_name_that_takes_in_no_parameters_just_like_the_other_tests_in_this_contract_and_simply_asserts_that_the_static_boolean_value_true_is_indeed_true(
    ) public pure {
        assertTrue(true, "Static boolean value true should be true");
    }
}
