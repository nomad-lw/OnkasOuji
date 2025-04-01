// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {VRF} from "vrf-solidity/contracts/VRF.sol";
import {LibString as Strings} from "solady/utils/LibString.sol";
import {stdJson} from "forge-std/StdJson.sol";

contract VRFTestData is Test {
    using stdJson for string;

    bytes32 public immutable SECRET_KEY;

    struct VrfDatai {
        bytes32 hash;
        bytes32 message;
        bytes proof;
        bytes public_key;
        uint256 secret_key;
    }

    struct VrfData {
        bytes32 hash;
        uint256 message;
        bytes proof;
        bytes public_key;
        uint256 secret_key;
    }

    constructor() {
        SECRET_KEY = bytes32(vm.envBytes("VRF_SECRET_KEY"));
        console.log("VRF_SECRET_KEY: ");
        console.logBytes32(SECRET_KEY);
    }

    // function get_public_key_as_point() public pure returns (uint256[2] memory) {
    //     uint256[2] memory PUBLIC_KEY_XY = [
    //         uint256(20149468923017862635785269351026469201343513335253737999994330121872194856517),
    //         uint256(45558802482409728232371975206855032011893935284936184167394243449917294149765)
    //     ];
    //     return PUBLIC_KEY_XY;
    // }

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

    function get_valid_static_vrf_proof()
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
        uint256 precomputed_beta = 0x612065e309e937ef46c2ef04d5886b9c6efd2991ac484ec64a9b014366fc5d81;
        require(bytes32(precomputed_beta) == beta, "Incorrect beta");
        pub_bytes = hex"032c8c31fc9f990c6b55e3865a184a4ce50e09481f2eaeb3e60ec1cea13a6ae645";
    }

    function zero_pad_b32(bytes memory unaligned) public pure returns (bytes memory padded) {
        if (unaligned.length % 32 == 0) {
            return unaligned;
        }
        uint256 padding = 32 - (unaligned.length % 32);
        padded = new bytes(unaligned.length + padding);
        for (uint256 i = 0; i < unaligned.length; i++) {
            padded[i + padding] = unaligned[i];
        }
    }

    function bytes_to_hex_string(bytes memory b) public pure returns (string memory) {
        string memory hexString = "";
        for (uint256 i = 0; i < b.length; i++) {
            hexString = string.concat(hexString, Strings.toHexStringNoPrefix(uint8(b[i]), 1));
        }
        return hexString;
    }

    function hexStringToBytes(string memory hexString) public pure returns (bytes memory) {
        // Check if the string has '0x' prefix and remove it if present
        bytes memory strBytes = bytes(hexString);
        uint256 startIndex = 0;
        if (strBytes.length >= 2 && strBytes[0] == "0" && (strBytes[1] == "x" || strBytes[1] == "X")) {
            startIndex = 2;
        }

        // Calculate the length of the bytes array (each byte is represented by 2 hex characters)
        uint256 len = (strBytes.length - startIndex) / 2;
        bytes memory result = new bytes(len);

        // Process each byte (2 hex characters)
        for (uint256 i = 0; i < len; i++) {
            uint8 highNibble = _hexCharToUint8(strBytes[startIndex + i * 2]);
            uint8 lowNibble = _hexCharToUint8(strBytes[startIndex + i * 2 + 1]);
            result[i] = bytes1(uint8((highNibble << 4) | lowNibble));
        }

        return result;
    }

    function _hexCharToUint8(bytes1 c) internal pure returns (uint8) {
        if (uint8(c) >= uint8(bytes1("0")) && uint8(c) <= uint8(bytes1("9"))) {
            return uint8(c) - uint8(bytes1("0"));
        }
        if (uint8(c) >= uint8(bytes1("a")) && uint8(c) <= uint8(bytes1("f"))) {
            return 10 + uint8(c) - uint8(bytes1("a"));
        }
        if (uint8(c) >= uint8(bytes1("A")) && uint8(c) <= uint8(bytes1("F"))) {
            return 10 + uint8(c) - uint8(bytes1("A"));
        }
        revert("Invalid hex character");
    }

    function generate_vrf_proof(bytes32 alpha)
        public
        returns (
            uint256[2] memory pk,
            uint256[4] memory proof,
            uint256[2] memory U,
            uint256[4] memory V,
            bytes32 beta,
            bytes memory encoded_proof,
            bytes memory encoded_pk
        )
    {
        console.log("Length of message (alpha):", alpha.length);
        // alpha = zero_pad_b32(alpha);
        // string memory encoded_alpha = bytes_to_hex_string(alpha);
        // assertEq(encoded_alpha, Strings.toHexStringNoPrefix(alpha));
        // string memory encoded_alpha = Strings.toHexStringNoPrefix(alpha);
        string memory encoded_alpha = Strings.toHexString(uint256(alpha), 32);

        console.log("alpha:");
        console.logBytes32(alpha);

        console.log("Revised length of message (alpha):", alpha.length);
        string[] memory inputs = new string[](8);
        string memory output_file_suffix = vm.toString(vm.unixTime());
        inputs[0] = "test/utils/gen_vrf/target/debug/gen_vrf";
        inputs[1] = "-o";
        inputs[2] = "prove";
        inputs[3] = "-m";
        inputs[4] = encoded_alpha;
        inputs[5] = "--silent";
        inputs[6] = "--json";
        inputs[7] = output_file_suffix;
        // inputs[6] = "--soft";
        console.log("Encoded alpha:", encoded_alpha);

        bytes memory res = vm.ffi(inputs);
        console.log("res:", string(res));
        assertEq(string(res), "Ok");
        VrfData memory vrf_data = load_vrf_proof(false, output_file_suffix);
        // VrfData memory vrf_data = parse_vrf_json(string(res));
        assertEq(bytes32(vrf_data.message), alpha);

        pk = VRF.decodePoint(vrf_data.public_key);
        proof = VRF.decodeProof(vrf_data.proof);
        encoded_proof = vrf_data.proof;
        encoded_pk = vrf_data.public_key;

        assertTrue(VRF.verify(pk, proof, bytes.concat(alpha)));

        (U, V) = VRF.computeFastVerifyParams(pk, proof, bytes.concat(alpha));
        beta = VRF.gammaToHash(proof[0], proof[1]);
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
            bytes memory pub_bytes
        )
    {
        return get_valid_static_vrf_proof();
    }

    function get_pk() public returns (uint256[2] memory) {
        (,,,,,, bytes memory public_key) = generate_vrf_proof(bytes32(hex"1337"));
        // VrfData memory vrf_data = load_vrf_proof(true);
        return VRF.decodePoint(public_key);
    }

    function parse_vrf_json(string memory json) internal pure returns (VrfData memory vrf_data) {
        bytes memory data = vm.parseJson(json);
        VrfDatai memory vrf_data_intermediate = abi.decode(data, (VrfDatai));
        vrf_data.hash = vrf_data_intermediate.hash;
        vrf_data.message = uint256(vrf_data_intermediate.message);
        console.log("Message:", vrf_data.message);
        vrf_data.proof = vrf_data_intermediate.proof;
        vrf_data.public_key = vrf_data_intermediate.public_key;
        vrf_data.secret_key = vrf_data_intermediate.secret_key;
    }

    function load_vrf_proof(bool dummy) public returns (VrfData memory vrf_data) {
        return load_vrf_proof(dummy, "");
    }

    function load_vrf_proof(bool dummy, string memory output_file) public returns (VrfData memory vrf_data) {
        string memory ROOT = vm.projectRoot();
        string memory PATH = string.concat(ROOT, "/vrf_proof", output_file, ".json");
        // vm.sleep(1000);
        string memory json = vm.readFile(PATH);
        console.log("Raw Data:", json);
        vrf_data = parse_vrf_json(json);
        if (dummy) {
            // console.log("Length of message:", vrf_data.message.length);
            assertEq(vrf_data.message, uint256(bytes32(hex"1337")));
            uint256[2] memory _pk = VRF.decodePoint(vrf_data.public_key);
            uint256[4] memory _proof = VRF.decodeProof(vrf_data.proof);
            assertTrue(VRF.verify(_pk, _proof, bytes.concat(bytes32(vrf_data.message))));
        }
    }
}

// IMPLEMENTATION NOTES
// vrf stack comprised of
// - ECVRF-SECP256K1-SHA256-TAI ??
// - EC: Secp256k1
//
// example data needed: pub-pem keys, alpha, beta values
