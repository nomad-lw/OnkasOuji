use hex;
use vrf::openssl::{CipherSuite, ECVRF};
use vrf::VRF;



fn main() {
    // Initialization of VRF context by providing a curve
    let mut vrf = ECVRF::from_suite(CipherSuite::SECP256K1_SHA256_TAI).unwrap();
    // Inputs: Secret Key, Public Key (derived) & Message
    let pre_pi = hex::decode("031f4dbca087a1972d04a07a779b7df1caa99e0f5db2aa21f3aecc4f9e10e85d0814faa89697b482daa377fb6b4a8b0191a65d34a6d90a8a2461e5db9205d4cf0bb4b2c31b5ef6997a585a9f1a72517b6f").unwrap();
    let p2hash = vrf.proof_to_hash(&pre_pi).unwrap();
    println!("Proof to Hash: {}", hex::encode(p2hash));
    // let secret_key =
    //     hex::decode("c9afa9d845ba75166b5c215767b1d6934e50c3db36e89b127b8a622b120f6721").unwrap();
    // let public_key = vrf.derive_public_key(&secret_key).unwrap();
    let public_key = &hex::decode("032c8c31fc9f990c6b55e3865a184a4ce50e09481f2eaeb3e60ec1cea13a6ae645").unwrap();
    let message: &[u8] = &hex::decode("73616d706c65").unwrap();
    println!("Message as hex: {}", hex::encode(message));
    if message.len() <= 32 {
        let mut uint256 = [0u8; 32];
        uint256[32 - message.len()..].copy_from_slice(message);
        println!("Message as uint256: {}", hex::encode(uint256));
    } else {
        println!("Message exceeds uint256 size");
    }
    // // VRF proof and hash output
    // let pi = vrf.prove(&secret_key, &message).unwrap();
    // let hash = vrf.proof_to_hash(&pi).unwrap();

    // // VRF proof verification (returns VRF hash output)
    let beta = vrf.verify(&public_key, &pre_pi, &message).unwrap();
    println!("Verification Result: {}", hex::encode(beta));
}
