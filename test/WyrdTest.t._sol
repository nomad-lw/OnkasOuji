// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {Wyrd} from "../src/Wyrd.sol";
import "./mocks/MockRandomizer.sol";
import "./mocks/MockPythEntropy.sol";
import "./utils/VRFTestData.sol";

// Concrete implementation of Wyrd for testing
contract TestWyrd is Wyrd {
    constructor(uint8 _flags, address _pyth_provider, address _pyth_entropy, address _randomizer, uint256[2] memory _sav_pk)
        Wyrd(_flags, _pyth_provider, _pyth_entropy, _randomizer, _sav_pk)
    {}

    // Expose internal function for testing
    function request_random(uint256 req_id, bytes32 alpha) external payable {
        _request_random(req_id, alpha);
    }
}

contract WyrdTest is Test {
    Wyrd internal wyrd;
    MockRandomizer internal randomizer;
    MockPythEntropy internal pythEntropy;

    uint8 internal constant FLAG_PYTH = 1 << 0;
    uint8 internal constant FLAG_RANDOMIZER = 1 << 1;
    uint8 internal constant FLAG_SAV = 1 << 2;

    address internal constant PYTH_PROVIDER = address(0x1234);
    uint256 internal constant INITIAL_BALANCE = 100 ether;

    event RandomnessRequested(uint256 indexed req_id, uint8 indexed flag);
    event RandomnessGenerated(uint256 indexed req_id, uint8 indexed flag);
    event RequestCompleted(uint256 indexed req_id);

    function setUp() public {
        randomizer = new MockRandomizer();
        pythEntropy = new MockPythEntropy();

        // Fund test contract
        vm.deal(address(this), INITIAL_BALANCE);
    }

    TestWyrd internal wyrd;
    MockRandomizer internal randomizer;
    MockPythEntropy internal pythEntropy;

    uint8 internal constant FLAG_PYTH = 1 << 0;
    uint8 internal constant FLAG_RANDOMIZER = 1 << 1;
    uint8 internal constant FLAG_SAV = 1 << 2;

    address internal constant PYTH_PROVIDER = address(0x1234);
    uint256 internal constant INITIAL_BALANCE = 100 ether;

    event RandomnessRequested(uint256 indexed req_id, uint8 indexed flag);
    event RandomnessGenerated(uint256 indexed req_id, uint8 indexed flag);
    event RequestCompleted(uint256 indexed req_id);

    function setUp() public {
        randomizer = new MockRandomizer();
        pythEntropy = new MockPythEntropy();

        // Fund test contract
        vm.deal(address(this), INITIAL_BALANCE);
    }

    function test_RandomizerOnly() public {
        wyrd = new TestWyrd(FLAG_RANDOMIZER, PYTH_PROVIDER, address(pythEntropy), address(randomizer), VRFTestData.get_public_key());

        uint256 reqId = 1;
        bytes32 alpha = bytes32(uint256(1));

        // Calculate and send fee
        uint256 fee = randomizer.estimateFee(100_000);
        vm.expectEmit(true, true, false, true);
        emit RandomnessRequested(reqId, FLAG_RANDOMIZER);
        wyrd.request_random{value: fee}(reqId, alpha);

        // Verify request status
        (bool active, uint8 remainingSources) = wyrd.get_request_status(reqId);
        assertTrue(active);
        assertEq(remainingSources, FLAG_RANDOMIZER);

        // Mock Randomizer callback
        uint256 requestId = uint256(keccak256(abi.encodePacked(block.timestamp, address(wyrd))));
        bytes32 beta = bytes32(uint256(2));

        uint256 gasBefore = gasleft();
        vm.prank(address(randomizer));
        wyrd.randomizerCallback(requestId, beta);
        uint256 gasUsed = gasBefore - gasleft();

        assertTrue(gasUsed < 100_000, "Randomizer callback gas too high");

        // Verify completion
        (active, remainingSources) = wyrd.get_request_status(reqId);
        assertFalse(active);
        assertEq(remainingSources, 0);

        (bytes32 rand, bool completed) = wyrd.get_random_value(reqId);
        assertTrue(completed);
        assertEq(rand, beta);
    }

    function test_SAVOnly() public {
        wyrd = new Wyrd(FLAG_SAV, PYTH_PROVIDER, address(pythEntropy), address(randomizer), VRFTestData.SAV_PUBLIC_KEY);

        uint256 reqId = 1;
        bytes32 alpha = bytes32(uint256(1));

        vm.expectEmit(true, true, false, true);
        emit RandomnessRequested(reqId, FLAG_SAV);
        wyrd._request_random{value: 0}(reqId, alpha);

        // Test with VRF test vectors
        bytes memory message = abi.encodePacked(alpha);
        (uint256[2] memory U, uint256[4] memory V) = wyrd.compute_fast_verify_params(VRFTestData.PROOF, message);

        uint256 gasBefore = gasleft();
        wyrd.sav_callback(reqId, message, VRFTestData.BETA, VRFTestData.PROOF, U, V);
        uint256 gasUsed = gasBefore - gasleft();

        assertTrue(gasUsed < 100_000, "SAV callback gas too high");

        (bool active, uint8 remainingSources) = wyrd.get_request_status(reqId);
        assertFalse(active);
        assertEq(remainingSources, 0);

        (bytes32 rand, bool completed) = wyrd.get_random_value(reqId);
        assertTrue(completed);
        assertEq(rand, VRFTestData.BETA);
    }

    function test_PythAndRandomizer() public {
        wyrd = new Wyrd(FLAG_PYTH | FLAG_RANDOMIZER, PYTH_PROVIDER, address(pythEntropy), address(randomizer), VRFTestData.SAV_PUBLIC_KEY);

        uint256 reqId = 1;
        bytes32 alpha = bytes32(uint256(1));

        // Calculate total fee
        (uint256 totalFee, uint128 pythFee, uint256 randomizerFee) = wyrd.calc_fee();

        vm.expectEmit(true, true, false, true);
        emit RandomnessRequested(reqId, FLAG_PYTH);
        vm.expectEmit(true, true, false, true);
        emit RandomnessRequested(reqId, FLAG_RANDOMIZER);

        wyrd._request_random{value: totalFee}(reqId, alpha);

        // Mock both callbacks
        uint64 pythSeq = uint64(block.timestamp);
        uint256 randSeq = uint256(keccak256(abi.encodePacked(block.timestamp, address(wyrd))));
        bytes32 pythBeta = bytes32(uint256(2));
        bytes32 randBeta = bytes32(uint256(3));

        // Pyth callback
        uint256 gasBefore = gasleft();
        pythEntropy.mockFulfill(pythSeq, pythBeta);
        uint256 gasUsed = gasBefore - gasleft();
        assertTrue(gasUsed < 500_000, "Pyth callback gas too high");

        // Randomizer callback
        gasBefore = gasleft();
        vm.prank(address(randomizer));
        wyrd.randomizerCallback(randSeq, randBeta);
        gasUsed = gasBefore - gasleft();
        assertTrue(gasUsed < 100_000, "Randomizer callback gas too high");

        (bool active, uint8 remainingSources) = wyrd.get_request_status(reqId);
        assertFalse(active);
        assertEq(remainingSources, 0);

        (bytes32 rand, bool completed) = wyrd.get_random_value(reqId);
        assertTrue(completed);
        assertEq(rand, pythBeta ^ randBeta);
    }

    // Continue with other combination tests...
}
