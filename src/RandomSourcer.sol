// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.26;

// Core imports
import {OwnableRoles} from "solady/auth/OwnableRoles.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// Interfaces
import {IEntropy} from "node_modules/@pythnetwork/entropy-sdk-solidity/IEntropy.sol";
import {IEntropyConsumer} from "node_modules/@pythnetwork/entropy-sdk-solidity/IEntropyConsumer.sol";

// Libraries
import {VRF} from "vrf-solidity/contracts/VRF.sol";

interface IRandomizer {
    // Makes a Randomizer VRF callback request with a callback gas limit
    function request(uint256 callbackGasLimit) external returns (uint256);
    function request(uint256 callbackGasLimit, uint256 confirmations) external returns (uint256);
    function clientWithdrawTo(address _to, uint256 _amount) external;
    // Estimates the VRF fee given a callback gas limit
    function estimateFee(uint256 callbackGasLimit) external view returns (uint256);
    // Gets the amount of ETH deposited and reserved for the client contract
    function clientBalanceOf(address _client) external view returns (uint256 deposit, uint256 reserved);
}

contract RandomSourcer is OwnableRoles, ReentrancyGuard, IEntropyConsumer {
    // constants
    uint8 internal constant FLAG_PYTH = 1 << 0;
    uint8 internal constant FLAG_RANDOMIZER = 1 << 1;
    uint8 internal constant FLAG_SAV = 1 << 2; // SAV = Self Attested VRFs
    uint256 public constant ROLE_SAV_PROVER = _ROLE_1;

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
    uint[2] public SAV_PUBLIC_KEY;

    // Events
    event RandomnessRequested(uint256 indexed req_id, uint8 indexed flag);
    event RandomnessGenerated(uint256 indexed req_id, uint8 indexed flag);
    event RequestCompleted(uint256 indexed req_id);
    event CallbackOnInactiveRequest(uint256 indexed req_id, uint8 indexed flag, uint256 sequence_number);
    event RandomnessSourcesUpdated(uint8 old_sources, uint8 new_sources);

    // Errors
    error CallerNotRandomizer();
    // error InvalidGameStatus(uint game_id, uint8 status);
    error InvalidVRFProof();
    error InsufficientFee(uint256 fee_supplied, uint256 required);

    constructor(uint8 _flags, address _pyth_provider, address _pyth_entropy, address _randomizer, uint[2] calldata _sav_pk) {
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

        SAV_PUBLIC_KEY = _sav_pk;
    }

    function calc_fee() public view returns (uint256) {
        uint256 fee;
        if (pyth_enabled) {
            fee = PYTH_ENTROPY.getFee(PYTH_PROVIDER);
        }
        if (randomizer_enabled) {
            fee += RANDOMIZER.estimateFee(100_000);
        }
        return fee;
    }

    /**
     * @dev Processes random number callback from any source.
     * @param req_id The ID of the request.
     * @param source_flag The flag indicating the source of the randomness.
     * @param beta The random value message provided by the entropy provider.
     */
    function process_callback(uint256 req_id, uint8 source_flag, bytes32 beta) internal virtual {
        req_executions[req_id] ^= source_flag;
        req_rand[req_id] ^= beta;
        emit RandomnessGenerated(req_id, source_flag);
        if (req_executions[req_id] == 0) {
            emit RequestCompleted(req_id);
        }
    }

    /**
     * @dev Returns the address of Pyth Entropy instance.
     * @dev IEntropyConsumer requirement
     */
    function getEntropy() internal view override returns (address) {
        return address(PYTH_ENTROPY);
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
        if (req_executions[req_id] & FLAG_PYTH == 0) {
            emit CallbackOnInactiveRequest(req_id, FLAG_PYTH, sequence_number);
            return;
        }
        process_callback(req_id, FLAG_PYTH, _beta);
    }

    /**
     * @dev Callback function for RandomizerAI requests
     * @param _id The ID of the request.
     * @param _beta The random value message being fed.
     */
    function randomizerCallback(uint256 _id, bytes32 _beta) external {
        //Callback can only be called by randomizer
        require(msg.sender == address(RANDOMIZER), CallerNotRandomizer());

        uint256 req_id = randomizer_cbidx_req[_id];
        if (req_executions[req_id] & FLAG_RANDOMIZER == 0) {
            emit CallbackOnInactiveRequest(req_id, FLAG_RANDOMIZER, _id);
            return;
        }
        process_callback(req_id, FLAG_RANDOMIZER, _beta);
    }

    // function functionUsingVRF(
    //     uint256[2] memory public _publicKey,
    //     uint256[4] memory public _proof,
    //     bytes memory _message)
    //   public returns (bool)
    //   {
    //     return VRF.verify(_publicKey, _proof, _message);
    //   }


    function set_sav_public_key(uint[2] memory _publicKey) public onlyRolesOrOwner(ROLE_SAV_PROVER) {
        SAV_PUBLIC_KEY = _publicKey;
    }


    /**
     * @dev Callback function for SAV (Self Attested VRF) requests
     * @param req_id The ID of the request, directly corresponds to the main randomness request id
     * @param _beta The random value message being fed.
     */
    function sav_callback(uint256 req_id, bytes32 _beta, uint[4] memory _proof) external onlyRolesOrOwner(ROLE_SAV_PROVER) {
        if (req_executions[req_id] & FLAG_SAV == 0) {
            emit CallbackOnInactiveRequest(req_id, FLAG_SAV, req_id);
            return;
        }

        if(!VRF.verify(SAV_PUBLIC_KEY, _proof, _beta)) revert InvalidVRFProof();
        process_callback(req_id, FLAG_SAV, _beta);
    }

    function get_request_status(uint256 req_id) public view returns (bool complete, uint8 remaining_sources) {
        uint8 status = req_executions[req_id];
        return (status == 0, status);
    }

    function _request_random(uint256 req_id, bytes32 alpha) public payable nonReentrant {
        require(req_id != 0, "Invalid request ID");
        require(req_executions[req_id] == 0, "Request already exists");

        uint256 available_fee = msg.value;
        uint256 total_required_fee = 0;

        if (pyth_enabled) {
            uint128 pyth_fee = PYTH_ENTROPY.getFee(PYTH_PROVIDER);
            total_required_fee += pyth_fee;
        }

        if (randomizer_enabled) {
            uint256 randomizer_fee = RANDOMIZER.estimateFee(100_000);
            total_required_fee += randomizer_fee;
        }

        if (available_fee < total_required_fee) {
            revert InsufficientFee(available_fee, total_required_fee);
        }

        if (pyth_enabled) {
            req_executions[req_id] |= FLAG_PYTH;
            uint128 pyth_fee = PYTH_ENTROPY.getFee(PYTH_PROVIDER);
            // if (available_fee < pyth_fee) revert InsufficientFee(msg.value, available_fee, pyth_fee);
            uint64 idx = PYTH_ENTROPY.requestWithCallback{value: pyth_fee}(PYTH_PROVIDER, alpha);
            pyth_cbidx_req[idx] = req_id;
            available_fee -= pyth_fee;
            emit RandomnessRequested(req_id, FLAG_PYTH);
        }

        if (randomizer_enabled) {
            req_executions[req_id] |= FLAG_RANDOMIZER;
            // uint256 randomizer_fee = RANDOMIZER.estimateFee(100_000);
            // check for available deposits

            // if (available_fee < randomizer_fee) revert InsufficientFee(msg.value, available_fee, randomizer_fee);
            uint256 idx = RANDOMIZER.request(100_000);
            randomizer_cbidx_req[idx] = req_id;
            emit RandomnessRequested(req_id, FLAG_RANDOMIZER);
        }

        if (sav_enabled) {
            // Self Attested VRFs are expected to be submitted by prover proactively (if enabled)
            req_executions[req_id] |= FLAG_SAV;
            emit RandomnessRequested(req_id, FLAG_SAV);
        }
    }

    function randomizerWithdraw(uint256 amount) external onlyOwner {
        RANDOMIZER.clientWithdrawTo(msg.sender, amount);
    }

    function get_random_value(uint256 req_id) external view returns (bytes32) {
        require(req_executions[req_id] == 0, "Request not completed");
        return req_rand[req_id];
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

    function set_sources(uint8 sources) public onlyOwner {
        uint8 old_sources = get_active_sources();
        pyth_enabled = sources & FLAG_PYTH != 0;
        randomizer_enabled = sources & FLAG_RANDOMIZER != 0;
        sav_enabled = sources & FLAG_SAV != 0;
        emit RandomnessSourcesUpdated(old_sources, sources);
    }

    function recover_eth() external onlyOwner {
        uint balance = address(this).balance;
        require(balance > 0, "No ETH/DMT to recover");
        (bool success,) = msg.sender.call{value: balance}("");
        require(success, "ETH/DMT transfer failed");
    }
}
