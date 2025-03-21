// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.26;

import {VRF} from "vrf-solidity/contracts/VRF.sol";

library VRFTestData {
    // // Public key components as separate constants
    // uint256 internal constant SAV_PUBLIC_KEY_X = 0x2c8c31fc9f990c6b55e3865a184a4ce50e09481f2eaeb3e60ec1cea13a6ae645;
    // uint256 internal constant SAV_PUBLIC_KEY_Y = 0x64b95e4fdb6948c0386e189b006a29f686769b011704275e4459822dc3328085;

    // // Proof components as separate constants
    // uint256 internal constant PROOF_GAMMA_X = 0x1f4dbca087a1972d04a07a779b7df1caa99e0f5db2aa21f3aecc4f9e10e85d08;
    // uint256 internal constant PROOF_GAMMA_Y = 0x21b6e2439257f7488de301945cdd2c9959c1ed2f58766dd3c958b38c9f37792f;
    // uint256 internal constant PROOF_C = 0x14faa89697b482daa377fb6b4a8b0191;
    // uint256 internal constant PROOF_S = 0xa65d34a6d90a8a2461e5db9205d4cf0bb4b2c31b5ef6997a585a9f1a72517b6f;

    // bytes32 internal constant BETA = 0x612065e309e937ef46c2ef04d5886b9c6efd2991ac484ec64a9b014366fc5d81;

    // // Helper function to get public key as array
    // function get_public_key() internal pure returns (uint256[2] memory) {
    //     return [SAV_PUBLIC_KEY_X, SAV_PUBLIC_KEY_Y];
    // }

    // // Helper function to get proof as array
    // function get_proof() internal pure returns (uint256[4] memory) {
    //     return [PROOF_GAMMA_X, PROOF_GAMMA_Y, PROOF_C, PROOF_S];
    // }

    bytes32 public constant SECRET_KEY = 0xe95387163cb7fef63eb29ff777082649e5501e9069da9ff36c8c038b4f0207f2; //?

    uint256 public constant PUBLIC_KEY_X = 20149468923017862635785269351026469201343513335253737999994330121872194856517;
    uint256 public constant PUBLIC_KEY_Y = 45558802482409728232371975206855032011893935284936184167394243449917294149765;

    function get_public_key_as_point() public pure returns (uint256[2] memory) {
        uint256[2] memory PUBLIC_KEY_XY = [
            uint256(20149468923017862635785269351026469201343513335253737999994330121872194856517),
            uint256(45558802482409728232371975206855032011893935284936184167394243449917294149765)
        ];
        return PUBLIC_KEY_XY;
    }

    function decodeProof(bytes memory _proof) public pure returns (uint256[4] memory) {
        return VRF.decodeProof(_proof);
    }

    function decodePoint(bytes memory _point) public pure returns (uint256[2] memory) {
        return VRF.decodePoint(_point);
    }

    function verify(uint256[2] memory _publicKey, uint256[4] memory _proof, bytes memory _message) public pure returns (bool) {
        return VRF.verify(_publicKey, _proof, _message);
    }

    function computeFastVerifyParams(uint256[2] memory _publicKey, uint256[4] memory _proof, bytes memory _message)
        public
        pure
        returns (uint256[2] memory, uint256[4] memory)
    {
        return VRF.computeFastVerifyParams(_publicKey, _proof, _message);
    }

    function get_valid_vrf_proof()
        public
        pure
        returns (
            uint256[2] memory pk,
            bytes memory alpha,
            uint256[2] memory U,
            uint256[4] memory V,
            bytes memory pi,
            bytes32 beta,
            uint256[4] memory proof,
            uint256 precomputed_beta,
            bytes memory pub_bytes
        )
    {
        pk = [0x2c8c31fc9f990c6b55e3865a184a4ce50e09481f2eaeb3e60ec1cea13a6ae645, 0x64b95e4fdb6948c0386e189b006a29f686769b011704275e4459822dc3328085];
        pi =
            hex"031f4dbca087a1972d04a07a779b7df1caa99e0f5db2aa21f3aecc4f9e10e85d0814faa89697b482daa377fb6b4a8b0191a65d34a6d90a8a2461e5db9205d4cf0bb4b2c31b5ef6997a585a9f1a72517b6f";
        // alpha = abi.encodePacked(uint256(0x73616d706c65));
        alpha = hex"73616d706c65";
        U = [0xc71cd5625cd61d65bd9f6b84292eae013fc50ea99a9a090c730c3a4c24c32cc7, 0xebe10326af2accc2f3a4eb8658d90e572061aa766d04e31f102b26e7065c9f26];
        // V = sH[2], cGamma[2]
        V = [
            0x3596f1f475c8999ffe35ccf7cebee7373ee40513ad467e3fc38600aa06d41bcf,
            0x825a3eb4f09a55637391c950ba5e25c1ea658a15f234c14ebec79e5c68bd4133,
            0x1c2a90c4c30f60e878d1fe317acf4f2e059300e3deaa1c949628096ecaf993b2,
            0x9d42bf0c35d765c2242712205e8f8b1ea588f470a6980b21bc9efb4ab33ae246
        ];
        uint256[2] memory gamma =
            [0x1f4dbca087a1972d04a07a779b7df1caa99e0f5db2aa21f3aecc4f9e10e85d08, 0x21b6e2439257f7488de301945cdd2c9959c1ed2f58766dd3c958b38c9f37792f];
        proof = [gamma[0], gamma[1], 0x14faa89697b482daa377fb6b4a8b0191, 0xa65d34a6d90a8a2461e5db9205d4cf0bb4b2c31b5ef6997a585a9f1a72517b6f];
        // Beta is the hash of gamma point
        beta = VRF.gammaToHash(gamma[0], gamma[1]);
        precomputed_beta = 0x612065e309e937ef46c2ef04d5886b9c6efd2991ac484ec64a9b014366fc5d81;
        pub_bytes = hex"032c8c31fc9f990c6b55e3865a184a4ce50e09481f2eaeb3e60ec1cea13a6ae645";
    }
}

// IMPLEMENTATION NOTES
// vrf stack comprised of
// - ECVRF-SECP256K1-SHA256-TAI ??
// - EC: Secp256k1
//
// example data needed: pub-pem keys, alpha, beta values
