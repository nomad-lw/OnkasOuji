// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.26;

/**
 * @title Wyrd
 * @notice Configurable randomness sourcing from external providers (Pyth Entropy, RandomizerAI) or ECVRF-based self attested VRFs
 * @author Sambot (https://github.com/nomad-lw/OnkasOuji/blob/main/src/RandomSourcer.sol)
 * @dev This contract is designed to be inherited by other contracts that need random numbers.
 *
 *
 *  .                                                                   .,
 *                             ii                                     ;LL.
 *                            ;LLi                                   :LfL;
 *                            tLLf.                                 .fLfL:
 *                           .fLfL;                                 1LfLf.
 *                           ;LffLt                                ;LfLLf.
 *                           tLfLfL,                              .fLffLf.
 *                           tLfLfL1                              1LfLfLf.
 *                          :LfLLLLf.                            ;LfLLfLf.
 *                          :LfLLLfL;.,,:;;;;i1111111ttt1111111i;fLfLLLLL,
 *                          tLfLLLLLffLLLLLLLLLLLLLLLLLLLLLLLLLLLLfLLLLLLft1i:,
 *                      .:itfLLLLLLLLLLfffffffffffffffffffffffffffLLLLLLLLLLLLLf1;,
 *                   .;1fLLLLLLLLLLLfLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLfffffLLLLLf1:.
 *                 ,1fLLLfffLLLLLLLLfLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLffffLLLf1,
 *              .;tLLLfffLLLLLLLLLLLfLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLfffLLLt;.
 *             :fLLffLLLLLLLLLLLLLLLfLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLfffLCf;
 *           .tLLffLLLLLLLLLLLLLLLLLfLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLfLi1L1.
 *          :fLffLLLLLLLLLLLLLLLLLLLfLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLfL1. ;Lf,
 *         ;LLfLLLLLfffffffffLLLLLLLfLLLLLLLLLLLLfffffffffffffffffffffLLLLLLLLLLLLLLLLLfL.   fLf.
 *        ,LLfLLLLLfLLLLLLLLLLLLffffffffffffffLLLLLLLLLLLLLLLLLLLLLLLLfLLLLLLLLLLLLLLLfLf,   ;LLt
 *        tLfLLLLLLL1i1111ftffLLLLLLLLLLLLLLLLLLLffft1111;;;i:::::::ifLfLLLLLLLLLLLLLLfLt    :Lff.
 *       :LfLLLLLfLi         ...,::;i;;;;::::,....                    ;LfLLLLLLLLLLLLLfLf.   :Lff.
 *       ,LffLLLLfL:                                                   iLfLLLLLLLLLLLLfLt.   :fLt
 *        iLffLLLfL;                                                    fLfLLLLLLLLLLLfLf.   1Ct.
 *         ;LLfLLfLt                                      ...,::::,..   tLfLLLLLLLLLLLfLf.  :Lt.
 *          :LLfLLfL:  .:i;;i;:,                        :t111iiiitf1,  :LfLLLLLLLLLLLLfLf. ,Li
 *           :fLLffLf, :i:::::::                 .,::f:               .tLfLLLLLLLLLLLffLf:i1:
 *             ifLLfLf,                  ::,,,:;;;i:if.              ,tLfLLLLLLLLffffLLLLt:
 *              .;tLLLLi.                :iii;;;;::::.             ,1fLfLfffffffLLLLLf1:.
 *                 :1tLCL1;,.                                .,:;1tLLffLLLLLLLLLft1;,
 *                    ,:1fLLfft11i;:::::::,,,,,,:;;;;;;i11ttffLCCCLLLLLLLfft1i;,.
 *                         .,::iii1tttttftLLLLLLLLLLLLLLLLLLLf1;;:::::,..
 *                                      ,1fLffffffffffffffffLff1,
 *                                    ,iLLLfLLLLLLLLLLLLLLLLLLLLLt,
 *                                   iLLLLfLLLLLLLLLLLLLLLLLLL1fLLL;
 *                                 ,fLfLf:1LfLLLLLLLLLLLLLLLfLt.fLLCt
 *                                it1fL1.,LfLLLLLLLLLLLLLLLLfLt .tftLt.
 *                              :fLffLt  tLfLLLLLLLLLLLLLLLLLLf, .ttfLf;
 *                             :LLffLf, ,LffffffffffffffffffLfL;  ;LffLLi
 *                            :LLLLLf,  1LLLLLLLLLLLLLLLLLLLLLLt   1LLLLC1
 *                           .ffffff:  .ffffffffffffffffffffffff,   tfffffi
 */

// Core imports
import {OwnableRoles} from "solady/auth/OwnableRoles.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// Interfaces
import {IWyrd} from "src/interfaces/IWyrd.sol";
import {IRandomizer} from "src/interfaces/ext/IRandomizer.sol";
import {IEntropy} from "node_modules/@pythnetwork/entropy-sdk-solidity/IEntropy.sol";
import {IEntropyConsumer} from "node_modules/@pythnetwork/entropy-sdk-solidity/IEntropyConsumer.sol";

// Libraries
import {VRF} from "vrf-solidity/contracts/VRF.sol";
import {EntropyStructs} from "node_modules/@pythnetwork/entropy-sdk-solidity/EntropyStructs.sol";

abstract contract Wyrd is IWyrd, OwnableRoles, ReentrancyGuard, IEntropyConsumer {
    // constants
    uint8 internal constant FLAG_PYTH = 1 << 0;
    uint8 internal constant FLAG_RANDOMIZER = 1 << 1;
    uint8 internal constant FLAG_SAV = 1 << 2; // SAV = Self Attested VRFs
    uint256 internal constant ROLE_OPERATOR = _ROLE_0;
    uint256 internal constant ROLE_SAV_PROVER = _ROLE_1;
    uint256 internal constant CALLBACK_GAS_LIMIT = 100_000;

    // interfaces
    address public immutable PYTH_PROVIDER;
    IEntropy public immutable PYTH_ENTROPY;
    IRandomizer public immutable RANDOMIZER;

    // storage
    bool public pyth_enabled;
    bool public randomizer_enabled;
    bool public sav_enabled;
    mapping(uint64 => uint256) internal pyth_cbidx_req;
    mapping(uint256 => uint256) internal randomizer_cbidx_req;
    mapping(uint256 => uint8) internal req_executions;
    mapping(uint256 => bytes32) internal req_rand;
    uint256[2] public SAV_PUB_KEY;

    /* ▀▀▀ Events ▀▀▀ */
    event RandomnessRequested(uint256 indexed req_id, uint8 indexed flag);
    event RandomnessGenerated(uint256 indexed req_id, uint8 indexed flag);
    event RequestCompleted(uint256 indexed req_id);
    event RequestAborted(uint256 indexed req_id);
    event CallbackOnInactiveRequest(uint256 indexed req_id, uint8 indexed flag, uint256 sequence_number);
    event RandomnessSourcesUpdated(uint8 old_sources, uint8 new_sources);

    /* ▀▀▀ Errors ▀▀▀ */
    error InvalidVRFProof();
    error InvalidRequest();
    error RequestCollision(uint256 req_id);
    error UnauthorizedCaller();
    error InsufficientFee(uint256 fee_supplied, uint256 required);

    constructor(uint8 _flags, address _pyth_provider, address _pyth_entropy, address _randomizer, uint256[2] memory _sav_pk) {
        require(_pyth_provider != address(0), "Invalid Pyth provider");
        require(_pyth_entropy != address(0), "Invalid Pyth entropy");
        require(_randomizer != address(0), "Invalid randomizer");

        _initializeOwner(msg.sender);
        _grantRoles(msg.sender, ROLE_SAV_PROVER);

        pyth_enabled = (_flags & FLAG_PYTH) != 0;
        randomizer_enabled = (_flags & FLAG_RANDOMIZER) != 0;
        sav_enabled = (_flags & FLAG_SAV) != 0;

        PYTH_ENTROPY = IEntropy(_pyth_entropy);
        PYTH_PROVIDER = _pyth_provider;

        RANDOMIZER = IRandomizer(_randomizer);

        SAV_PUB_KEY = _sav_pk;
    }

    /* ▀▀▀ View/Pure Functions ▀▀▀ */

    function calc_fee() public view returns (uint256 total, uint128 fee_pyth, uint256 fee_randomizer) {
        if (pyth_enabled) {
            fee_pyth = get_pyth_fee();
        }
        if (randomizer_enabled) {
            fee_randomizer = get_randomizer_fee(false);
        }
        return (uint256(fee_pyth) + fee_randomizer, fee_pyth, fee_randomizer);
    }

    function get_request_status(uint256 req_id) public view returns (bool active, uint8 remaining_sources) {
        uint8 status = req_executions[req_id];
        return (status == 0, status);
    }

    function get_random_value(uint256 req_id) external view returns (bytes32 rand, bool completed) {
        completed = req_executions[req_id] == 0;
        return (req_rand[req_id], completed);
    }

    function get_active_sources() public view returns (uint8) {
        uint8 source;
        if (pyth_enabled) {
            source |= FLAG_PYTH;
        }
        if (randomizer_enabled) {
            source |= FLAG_RANDOMIZER;
        }
        if (sav_enabled) {
            source |= FLAG_SAV;
        }
        return source;
    }

    /* ▀▀▀ Source-Specific Functions ▀▀▀ */

    /// Pyth Entropy

    /**
     * @dev Returns the address of Pyth Entropy instance.
     * @dev IEntropyConsumer requirement
     */
    function getEntropy() internal view override returns (address) {
        return address(PYTH_ENTROPY);
    }

    function get_pyth_fee() public view returns (uint128) {
        return PYTH_ENTROPY.getFee(PYTH_PROVIDER);
    }

    function get_pyth_request(uint64 src_id) public view returns (EntropyStructs.Request memory req) {
        return PYTH_ENTROPY.getRequest(PYTH_PROVIDER, src_id);
    }

    /**
     * @dev Callback function for Pyth Entropy requests.
     * @param sequence_number The sequence number of the entropy request.
     * @param _provider The address of the entropy provider. This gets validated in the _entropyCallback function.
     * @param _beta The random value message provided by the entropy provider.
     */
    function entropyCallback(uint64 sequence_number, address _provider, bytes32 _beta) internal override {
        // Handle the entropy callback, caller check handled by _entropyCallback
        uint256 req_id = pyth_cbidx_req[sequence_number];
        process_callback(req_id, uint256(sequence_number), FLAG_PYTH, _beta);
    }

    /// Randomizer AI

    function get_randomizer_fee(bool atomic) public view returns (uint256) {
        uint256 fee = RANDOMIZER.estimateFee(CALLBACK_GAS_LIMIT);
        if (!atomic) {
            uint256 bal = get_randomizer_balance(true);
            fee = bal >= fee ? 0 : fee - bal;
        }
        return fee;
    }

    function get_randomizer_balance(bool liquid) public view returns (uint256) {
        (uint256 deposit, uint256 reserved) = RANDOMIZER.clientBalanceOf(address(this));
        return liquid ? deposit - reserved : deposit;
    }

    /**
     * @dev Callback function for RandomizerAI requests
     * @param _id The ID of the request.
     * @param _beta The random value message being fed.
     */
    function randomizerCallback(uint256 _id, bytes32 _beta) external {
        //Callback can only be called by randomizer
        if (msg.sender != address(RANDOMIZER)) revert UnauthorizedCaller();

        uint256 req_id = randomizer_cbidx_req[_id];

        process_callback(req_id, _id, FLAG_RANDOMIZER, _beta);
    }

    function randomizer_deposit(uint256 amount) public onlyRolesOrOwner(ROLE_OPERATOR) {
        RANDOMIZER.clientDeposit{value: amount}(address(this));
    }

    function randomizer_withdraw(uint256 amount) external onlyRolesOrOwner(ROLE_OPERATOR) {
        RANDOMIZER.clientWithdrawTo(msg.sender, amount);
    }

    /// Self Attested VRF

    function compute_fast_verify_params(uint256[4] memory _proof, bytes memory _alpha) public view returns (uint256[2] memory U, uint256[4] memory V) {
        return VRF.computeFastVerifyParams(SAV_PUB_KEY, _proof, _alpha);
    }

    // takes in expanded proof (derived from ECVRF_decode_proof)
    // returns beta
    function decoded_proof_to_hash(uint256[4] memory pi) public pure returns (bytes32) {
        return VRF.gammaToHash(pi[0], pi[1]);
    }

    function verify_beta(uint256[4] memory _proof, bytes memory _beta) public view returns (bool) {
        return VRF.verify(SAV_PUB_KEY, _proof, abi.encodePacked(_beta));
    }

    /**
     * @dev Callback function for SAV (Self Attested VRF) requests
     * @param req_id The ID of the request, directly corresponds to the main randomness request id
     * @param beta The random value message being fed.
     */
    function sav_callback(
        uint256 req_id,
        bytes memory _alpha,
        bytes32 beta,
        uint256[4] memory _proof,
        uint256[2] memory _U,
        uint256[4] memory _V
    ) external onlyRolesOrOwner(ROLE_SAV_PROVER) {
        if (decoded_proof_to_hash(_proof) != beta) revert InvalidVRFProof();
        if (!VRF.fastVerify(SAV_PUB_KEY, _proof, _alpha,_U,_V)) revert InvalidVRFProof();
        process_callback(req_id, req_id, FLAG_SAV, beta);
    }

    function set_sav_public_key(uint256[2] memory _publicKey) public onlyRolesOrOwner(ROLE_SAV_PROVER) {
        SAV_PUB_KEY = _publicKey;
    }

    /* ▀▀▀ Core Functions ▀▀▀ */

    function set_sources(uint8 sources) public onlyOwner {
        uint8 old_sources = get_active_sources();
        pyth_enabled = sources & FLAG_PYTH != 0;
        randomizer_enabled = sources & FLAG_RANDOMIZER != 0;
        sav_enabled = sources & FLAG_SAV != 0;
        emit RandomnessSourcesUpdated(old_sources, sources);
    }

    /// @notice Request random number with required fee paid in transaction
    /// @dev Fee handling is per-request basis, ensuring funds are available for each request
    /// @param req_id Unique identifier for the request
    /// @param alpha Seed (plaintext, predictable) for the pseudo-random function
    /// @custom:security Fee amount is validated against all enabled sources before processing
    function _request_random(uint256 req_id, bytes32 alpha) internal onlyRolesOrOwner(ROLE_OPERATOR) nonReentrant {
        if (req_id == 0) revert InvalidRequest(); // unnecessary?
        if (req_executions[req_id] != 0) revert RequestCollision(req_id);

        uint256 available_fee = msg.value;
        (uint256 required_fee, uint128 pyth_fee, uint256 randomizer_fee) = calc_fee();

        if (available_fee < required_fee) {
            revert InsufficientFee(available_fee, required_fee);
        }

        if (pyth_enabled) {
            req_executions[req_id] |= FLAG_PYTH;
            uint64 idx = PYTH_ENTROPY.requestWithCallback{value: pyth_fee}(PYTH_PROVIDER, alpha);
            pyth_cbidx_req[idx] = req_id;
            available_fee -= pyth_fee;
            emit RandomnessRequested(req_id, FLAG_PYTH);
        }

        if (randomizer_enabled) {
            req_executions[req_id] |= FLAG_RANDOMIZER;
            if (randomizer_fee > 0) randomizer_deposit(available_fee); // allow deposit buffer
            uint256 idx = RANDOMIZER.request(CALLBACK_GAS_LIMIT);
            randomizer_cbidx_req[idx] = req_id;
            emit RandomnessRequested(req_id, FLAG_RANDOMIZER);
        }

        if (sav_enabled) {
            // Self Attested VRFs are expected to be submitted by prover proactively (if enabled)
            req_executions[req_id] |= FLAG_SAV;
            emit RandomnessRequested(req_id, FLAG_SAV);
        }
    }

    /**
     * @dev Processes random number callback from any source.
     * @param req_id The ID of the request.
     * @param src_flag The flag indicating the source of the randomness.
     * @param beta The random value message provided by the entropy provider.
     */
    function process_callback(uint256 req_id, uint256 src_id, uint8 src_flag, bytes32 beta) internal virtual {
        if (req_executions[req_id] & src_flag == 0) {
            emit CallbackOnInactiveRequest(req_id, src_flag, src_id);
            return;
        }
        req_executions[req_id] ^= src_flag;
        req_rand[req_id] ^= beta;
        emit RandomnessGenerated(req_id, src_flag);
        if (req_executions[req_id] == 0) {
            emit RequestCompleted(req_id);
        }
    }

    function abort_request(uint256 req_id) external onlyRolesOrOwner(ROLE_OPERATOR) {
        if (req_executions[req_id] == 0) {
            emit RequestAborted(req_id);
            // delete req_rand[req_id]; // retain partial rands
        }
    }

    /* ▀▀▀ Administrative Functions ▀▀▀ */

    function recover_eth() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No ETH/DMT to recover");
        (bool success,) = msg.sender.call{value: balance}("");
        require(success, "ETH/DMT transfer failed");
    }
}
