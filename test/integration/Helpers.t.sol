// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {Wyrd} from "src/Wyrd.sol";
import {OnkasOujiGame} from "src/OnkasOujiGame.sol";
import {OwnableRoles} from "solady/auth/OwnableRoles.sol";
import "test/config.sol" as cfg;
import {VRFTestData} from "test/utils/VRFTestData.sol";
import {MockPythEntropy, MockRandomizer} from "test/mocks/MockRandomProviders.t.sol";
import {IEntropy} from "@pythnetwork/entropy-sdk-solidity/IEntropy.sol";
import {IRandomizer} from "src/interfaces/ext/IRandomizer.sol";
import {IWyrd} from "src/interfaces/IWyrd.sol";

interface ITestableWyrd is IWyrd {
    function vrf_tester() external returns (VRFTestData);

    function request_random(uint256 req_id, bytes32 alpha) external payable;

    // Expose internal variables for testing
    function get_role_operator() external pure returns (uint256);

    function get_role_sav_prover() external pure returns (uint256);

    function get_store_alpha_inputs() external view returns (bool);

    function pyth_cbidx_req(uint64 seq_num) external view returns (uint256);
}

contract TestableWyrd is Wyrd, ITestableWyrd {
    VRFTestData internal _vrf_tester;

    constructor(uint8 _flags, address _pyth_entropy, address _pyth_provider, address _randomizer, uint256[2] memory _sav_pk, bool _store_alpha)
        Wyrd(_flags, _pyth_entropy, _pyth_provider, _randomizer, _sav_pk, _store_alpha)
    {
        _vrf_tester = new VRFTestData();
    }

    function vrf_tester() public returns (VRFTestData) {
        return _vrf_tester;
    }

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

    function pyth_cbidx_req(uint64 seq_num) external view returns (uint256) {
        return _pyth_cbidx_req[seq_num];
    }
}

contract TestableOnkasOujiGame is ITestableWyrd, OnkasOujiGame {
    VRFTestData internal _vrf_tester;

    constructor(
        address _nft_contract,
        address _token_contract,
        address _pyth_entropy,
        address _pyth_provider,
        address _randomizer,
        uint256[2] memory _sav_pk,
        address _marketing_wallet
    ) OnkasOujiGame(_nft_contract, _token_contract, _pyth_entropy, _pyth_provider, _randomizer, _sav_pk, _marketing_wallet) {
        _vrf_tester = new VRFTestData();
    }

    function vrf_tester() public returns (VRFTestData) {
        return _vrf_tester;
    }

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

    function pyth_cbidx_req(uint64 seq_num) external view returns (uint256) {
        return _pyth_cbidx_req[seq_num];
    }
}

interface IMockEntropy is IEntropy {
    function triggerCallback(uint64 sequenceNumber) external;

    function getLatestSequenceNumber(address provider) external view returns (uint64);
}

abstract contract WyrdTestHelpers is Test {
    uint8 public constant FLAG_PYTH = cfg.FLAG_PYTH;
    uint8 public constant FLAG_RANDOMIZER = cfg.FLAG_RANDOMIZER;
    uint8 public constant FLAG_SAV = cfg.FLAG_SAV;
    Wyrd wyrd;
    ITestableWyrd twyrd;

    // Mock providers
    MockPythEntropy mock_pyth_entropy;
    MockRandomizer mock_randomizer;

    function grant_roles(address user, uint256 roles) internal {
        grant_roles(address(wyrd), user, roles);
    }

    function grant_roles(address ca, address user, uint256 roles) public {
        uint256 new_roles = OwnableRoles(ca).rolesOf(user) | roles;
        vm.startPrank(cfg.ADDR_DEPLOYER);
        vm.expectEmit(true, true, false, true, ca);
        emit OwnableRoles.RolesUpdated(user, new_roles);
        OwnableRoles(ca).grantRoles(user, roles);
        vm.stopPrank();
    }

    function revoke_roles(address user, uint256 roles) internal {
        revoke_roles(address(wyrd), user, roles);
    }

    function revoke_roles(address ca, address user, uint256 roles) public {
        uint256 new_roles = OwnableRoles(ca).rolesOf(user) & ~roles;
        console.log("Old roles for user:", OwnableRoles(ca).rolesOf(user));
        console.log("Revoking roles:", roles);
        console.log("Expected new roles:", new_roles);
        vm.startPrank(cfg.ADDR_DEPLOYER);
        vm.expectEmit(true, true, false, true, ca);
        emit OwnableRoles.RolesUpdated(user, new_roles);
        OwnableRoles(ca).revokeRoles(user, roles);
        vm.stopPrank();
    }

    function make_request(uint256 req_id, bytes32 alpha) internal {
        (uint256 required_fee,,) = wyrd.calc_fee();
        vm.deal(cfg.ADDR_OPERATOR, required_fee);

        uint8 active_sources = wyrd.get_active_sources();
        console.log("Active sources:", active_sources);
        if (active_sources & cfg.FLAG_PYTH != 0) {
            vm.expectEmit(true, true, true, true, address(wyrd));
            emit Wyrd.RandomnessRequested(req_id, cfg.FLAG_PYTH);
        }
        if (active_sources & cfg.FLAG_RANDOMIZER != 0) {
            vm.expectEmit(true, true, true, true, address(wyrd));
            emit Wyrd.RandomnessRequested(req_id, cfg.FLAG_RANDOMIZER);
        }
        if (active_sources & cfg.FLAG_SAV != 0) {
            vm.expectEmit(true, true, true, true, address(wyrd));
            emit Wyrd.RandomnessRequested(req_id, cfg.FLAG_SAV);
        }

        vm.prank(cfg.ADDR_OPERATOR);
        twyrd.request_random{value: required_fee}(req_id, alpha);
    }

    // 3 params
    function verify_request_status(uint256 req_id, bool req_active, uint8 expected_sources) internal view returns (uint8 active_sources) {
        active_sources = verify_request_status(req_id, req_active, expected_sources, false, 0);
    }

    // 4 params
    function verify_request_status(uint256 req_id, bool req_active, bool flag_enabled, uint8 flag) internal view returns (uint8 active_sources) {
        bool active;
        (active, active_sources) = wyrd.get_request_status(req_id);
        active_sources = verify_request_status(req_id, req_active, active_sources, flag_enabled, flag);
    }

    // 5 params
    function verify_request_status(uint256 req_id, bool req_active, uint8 expected_sources, bool flag_enabled, uint8 flag)
        internal
        view
        returns (uint8 active_sources)
    {
        bool active;
        (active, active_sources) = wyrd.get_request_status(req_id);
        assertEq(active, req_active, "Request active status mismatch");
        assertEq(active_sources, expected_sources, "Remaining sources mismatch");
        assertTrue((active_sources & flag != 0) == flag_enabled, "Flag mismatch");
        // return active_sources;
    }

    function verify_random_value(uint256 req_id, bool expected_completed) internal view {
        (bytes32 rand, bool completed) = wyrd.get_random_value(req_id);
        assertEq(completed, expected_completed, "Random value completion status mismatch");
        assertNotEq(rand, bytes32(0), "Random value should not be zero");
    }

    // Helper function to verify SAV VRF data
    function dry_verify_sav_vrf_data(
        uint256[2] memory pk,
        bytes memory pub,
        bytes memory pi,
        uint256[4] memory proof,
        bytes memory alpha,
        bytes32 beta,
        uint256[2] memory U,
        uint256[4] memory V
    ) internal {
        uint256[2] memory decoded_pk = twyrd.vrf_tester().decodePoint(pub);
        assertEq(decoded_pk[0], pk[0]);
        assertEq(decoded_pk[1], pk[1]);

        uint256[4] memory decoded_proof = twyrd.vrf_tester().decodeProof(pi);
        assertEq(decoded_proof[0], proof[0]);
        assertEq(decoded_proof[1], proof[1]);
        assertEq(decoded_proof[2], proof[2]);
        assertEq(decoded_proof[3], proof[3]);

        bool local_verify = twyrd.vrf_tester().verify(pk, proof, alpha);
        assertTrue(local_verify, "Local proof verification failed");

        (uint256[2] memory _U, uint256[4] memory _V) = wyrd.compute_fast_verify_params(proof, alpha);
        console.log("Passed U values:");
        console.log(U[0], U[1]);
        console.log("Passed V values:");
        console.log(V[0], V[1], V[2], V[3]);
        console.log("Computed U values:");
        console.log(_U[0], _U[1]);
        console.log("Computed V values:");
        console.log(_V[0], _V[1], _V[2], _V[3]);
        assertTrue(U[0] == _U[0] && U[1] == _U[1], "U values should match");
        assertTrue(V[0] == _V[0] && V[1] == _V[1] && V[2] == _V[2] && V[3] == _V[3], "V values should match");
    }

    function trigger_pyth_callback() internal {
        address ca = address(mock_pyth_entropy);
        uint64 idx = IMockEntropy(ca).getLatestSequenceNumber(cfg.ADDR_PYTH_PROVIDER);
        trigger_pyth_callback(idx, ca);
    }

    function trigger_pyth_callback(uint64 sequence_num) internal {
        trigger_pyth_callback(sequence_num, address(mock_pyth_entropy));
    }

    function trigger_pyth_callback(uint64 sequence_num, address mock_pyth) public {
        // Check request status has pyth enabled
        uint256 req_id = twyrd.pyth_cbidx_req(sequence_num);
        verify_request_status(req_id, true, true, FLAG_PYTH);

        // Check for RandomnessGenerated event
        vm.expectEmit(true, true, false, true, address(wyrd));
        emit Wyrd.RandomnessGenerated(req_id, FLAG_PYTH);
        vm.prank(cfg.ADDR_PYTH_PROVIDER);
        IMockEntropy(mock_pyth).triggerCallback(sequence_num);
    }

    function trigger_randomizer_callback() internal {
        uint256 idx = uint256(keccak256(abi.encodePacked(block.timestamp, address(wyrd))));
        trigger_randomizer_callback(idx);
    }

    function trigger_randomizer_callback(uint256 idx) internal {
        trigger_randomizer_callback(idx, address(mock_randomizer));
    }

    function trigger_randomizer_callback(uint256 randomizer_req_id, address prank_addr) internal {
        bytes32 randomizer_result = keccak256(abi.encodePacked("randomizer", randomizer_req_id));
        vm.prank(prank_addr);
        wyrd.randomizerCallback(randomizer_req_id, randomizer_result);
    }

    function trigger_randomizer_callback(uint256 randomizer_req_id, address prank_addr, address wyrd_addr) public {
        bytes32 randomizer_result = keccak256(abi.encodePacked("randomizer", randomizer_req_id));
        vm.prank(prank_addr);
        Wyrd(wyrd_addr).randomizerCallback(randomizer_req_id, randomizer_result);
    }

    function sav_update_public_key() public {
        uint[2] memory pk = twyrd.vrf_tester().get_pk();
        vm.warp(block.timestamp + 5 hours);
        vm.prank(cfg.ADDR_SAV_PROVER);
        wyrd.set_sav_public_key(pk);
    }

    function trigger_sav_callback(uint256 req_id) internal {
        // sav triggers,
        // first, lookup alpha value
        // prove it -> get hash, pi
        // submit
        bytes32 alpha = wyrd.get_alpha(req_id);
        (uint256[2] memory pk, uint256[4] memory proof, uint256[2] memory U, uint256[4] memory V, bytes32 beta, bytes memory pi, bytes memory pub) =
            twyrd.vrf_tester().generate_vrf_proof(alpha);

        dry_verify_sav_vrf_data(pk, pub, pi, proof, bytes.concat(alpha), beta, U, V);

        // Check req_executions value before callback
        uint8 remaining_sources_before = verify_request_status(req_id, true, true, FLAG_SAV);

        // Compute the expected remaining sources after the callback
        uint8 expected_remaining_sources_after = remaining_sources_before ^ FLAG_SAV;

        vm.startPrank(cfg.ADDR_SAV_PROVER);
        vm.expectEmit(true, true, false, true, address(wyrd));
        emit Wyrd.RandomnessGenerated(req_id, FLAG_SAV);
        if (expected_remaining_sources_after == 0) {
            vm.expectEmit(true, true, false, true, address(wyrd));
            emit Wyrd.RequestCompleted(req_id);
        }
        wyrd.sav_callback(req_id, bytes.concat(alpha), beta, proof, U, V);
        vm.stopPrank();

        // Check req_executions value after callback
        verify_request_status(req_id, expected_remaining_sources_after != 0, expected_remaining_sources_after, false, FLAG_SAV);
    }

    function ext_process_request_callbacks(uint256 req_id) internal {
        // wyrd = Wyrd(_wyrd);
        uint8 sources = twyrd.get_active_sources();
        verify_request_status(req_id, true, sources);
        console.log("Processing sources:", sources);
        if (sources & cfg.FLAG_PYTH != 0) {
            trigger_pyth_callback();
        }
        if (sources & cfg.FLAG_RANDOMIZER != 0) {
            trigger_randomizer_callback();
        }
        if (sources & cfg.FLAG_SAV != 0) {
            trigger_sav_callback(req_id);
        }
    }
}

abstract contract OnkasOujiGameTestHelpers is WyrdTestHelpers {}
