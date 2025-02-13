// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.26;

interface IWyrd {
    /* ▀▀▀ Events ▀▀▀ */
    // event RandomnessRequested(uint256 indexed req_id, uint8 indexed flag);
    // event RandomnessGenerated(uint256 indexed req_id, uint8 indexed flag);
    // event RequestCompleted(uint256 indexed req_id);
    // event RequestAborted(uint256 indexed req_id);
    // event CallbackOnInactiveRequest(uint256 indexed req_id, uint8 indexed flag, uint256 sequence_number);
    // event RandomnessSourcesUpdated(uint8 old_sources, uint8 new_sources);

    /* ▀▀▀ View/Pure Functions ▀▀▀ */
    function calc_fee() external view returns (uint256 total_fee, uint128 pyth_fee, uint256 randomizer_fee);
    function get_request_status(uint256 req_id) external view returns (bool active, uint8 remaining_sources);
    function get_random_value(uint256 req_id) external view returns (bytes32 rand, bool completed);
    function get_active_sources() external view returns (uint8);

    function get_pyth_fee() external view returns (uint128);
    function get_randomizer_fee(bool atomic) external view returns (uint256);
    function get_randomizer_balance(bool liquid) external view returns (uint256);

    function compute_fast_verify_params(uint256[4] memory _proof, bytes memory _alpha)
        external
        view
        returns (uint256[2] memory U, uint256[4] memory V);
    function decoded_proof_to_hash(uint256[4] memory pi) external pure returns (bytes32);
    function verify_beta(uint256[4] memory _proof, bytes memory _beta) external view returns (bool);

    /* ▀▀▀ External Functions ▀▀▀ */
    function randomizerCallback(uint256 _id, bytes32 _beta) external;
    function sav_callback(uint256 req_id, bytes memory _alpha, bytes32 beta, uint256[4] memory _proof, uint256[2] memory _U, uint256[4] memory _V)
        external;
    function set_sav_public_key(uint256[2] memory _public_key) external;
    function set_sources(uint8 sources) external;
    function randomizer_deposit(uint256 amount) external;
    function randomizer_withdraw(uint256 amount) external;
    function abort_request(uint256 req_id) external;
    function recover_eth() external;
}
