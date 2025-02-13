// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.26;

library VRFTestData {
    // Public key components as separate constants
    uint256 internal constant SAV_PUBLIC_KEY_X = 0x2c8c31fc9f990c6b55e3865a184a4ce50e09481f2eaeb3e60ec1cea13a6ae645;
    uint256 internal constant SAV_PUBLIC_KEY_Y = 0x64b95e4fdb6948c0386e189b006a29f686769b011704275e4459822dc3328085;

    // Proof components as separate constants
    uint256 internal constant PROOF_GAMMA_X = 0x1f4dbca087a1972d04a07a779b7df1caa99e0f5db2aa21f3aecc4f9e10e85d08;
    uint256 internal constant PROOF_GAMMA_Y = 0x21b6e2439257f7488de301945cdd2c9959c1ed2f58766dd3c958b38c9f37792f;
    uint256 internal constant PROOF_C = 0x14faa89697b482daa377fb6b4a8b0191;
    uint256 internal constant PROOF_S = 0xa65d34a6d90a8a2461e5db9205d4cf0bb4b2c31b5ef6997a585a9f1a72517b6f;

    bytes32 internal constant BETA = 0x612065e309e937ef46c2ef04d5886b9c6efd2991ac484ec64a9b014366fc5d81;

    // Helper function to get public key as array
    function get_public_key() internal pure returns (uint256[2] memory) {
        return [SAV_PUBLIC_KEY_X, SAV_PUBLIC_KEY_Y];
    }

    // Helper function to get proof as array
    function get_proof() internal pure returns (uint256[4] memory) {
        return [PROOF_GAMMA_X, PROOF_GAMMA_Y, PROOF_C, PROOF_S];
    }
}
