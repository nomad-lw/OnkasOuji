// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.26;

// Core imports
import {OwnableRoles} from "solady/auth/OwnableRoles.sol";

// Interfaces
import {IEntropy} from "node_modules/@pythnetwork/entropy-sdk-solidity/IEntropy.sol";
import {IEntropyConsumer} from "node_modules/@pythnetwork/entropy-sdk-solidity/IEntropyConsumer.sol";

interface IRandomizer {
    function request(uint256 callbackGasLimit) external returns (uint256);
    function request(uint256 callbackGasLimit, uint256 confirmations) external returns (uint256);
    function clientWithdrawTo(address _to, uint256 _amount) external;
}

abstract contract RandomSourcer is IEntropyConsumer, IRandomizer, OwnableRoles {
    // constants
    uint8 internal constant FLAG_PYTH = 1 << 0;
    uint8 internal constant FLAG_RANDOMIZER = 1 << 1;
    uint8 internal constant FLAG_SAV = 1 << 2; // Self Attested VRFs

    // interfaces
    address public immutable PYTH_PROVIDER;
    IEntropy public immutable PYTH_ENTROPY;
    IRandomizer public immutable RANDOMIZER;

    // storage
    bool public pyth_enabled;
    bool public randomizer_enabled;
    bool public sav_enabled;
    mapping(uint64 => uint256) internal _pyth_cbidx_gameid;
    mapping(uint256 => uint256) internal _randomizer_cbidx_gameid;
    mapping(uint256 => uint256) internal _sav_cbidx_gameid;
    mapping(uint256 => uint8) internal _gameid_cb_exec;
    mapping(uint256 => bytes32) internal _gameid_rands;

    // Events
    event RandomnessGenerated(uint256 indexed game_id, uint8 indexed flag);
    event DuplicateCallback(uint256 indexed game_id, uint8 indexed flag, uint256 sequence_number);

    // Errors
    error CallerNotRandomizer();

    constructor(uint8 _flags, address _pyth_provider, address _pyth_entropy, address _randomizer) {
        pyth_enabled = (_flags & FLAG_PYTH) != 0;
        randomizer_enabled = (_flags & FLAG_RANDOMIZER) != 0;
        sav_enabled = (_flags & FLAG_SAV) != 0;

        PYTH_ENTROPY = IEntropy(_pyth_entropy);
        PYTH_PROVIDER = _pyth_provider;

        RANDOMIZER = IRandomizer(_randomizer);
    }

    function getEntropy() internal view override returns (address) {
        // for pyth
        return address(PYTH_ENTROPY);
    }

    function get_fee() public view returns (uint256) {
        return PYTH_ENTROPY.getFee(PYTH_PROVIDER);
    }

    function entropyCallback(uint64 sequence_number, address _provider, bytes32 random_number) internal override {
        // Handle the entropy callback, caller chack handled by _entropyCallback
        uint256 game_id = _pyth_cbidx_gameid[sequence_number];
        if (_gameid_cb_exec[game_id] & FLAG_PYTH != 0) {
            emit DuplicateCallback(game_id, FLAG_PYTH, sequence_number);
            return;
        }
        _gameid_cb_exec[game_id] |= FLAG_PYTH;
        _gameid_rands[game_id] ^= random_number;
        emit RandomnessGenerated(game_id, FLAG_PYTH);
    }

    function randomizerCallback(uint256 _id, bytes32 _value) external {
        //Callback can only be called by randomizer
        require(msg.sender == address(RANDOMIZER), CallerNotRandomizer());

        uint256 game_id = _randomizer_cbidx_gameid[_id];
        if(_gameid_cb_exec[game_id] & FLAG_RANDOMIZER != 0) {
            emit DuplicateCallback(game_id, FLAG_RANDOMIZER, _id);
            return;
        }
        _gameid_cb_exec[game_id] |= FLAG_RANDOMIZER;
        _gameid_rands[game_id] ^= _value;
        emit RandomnessGenerated(game_id, FLAG_RANDOMIZER);
    }

    function randomizerWithdraw(uint256 amount) external onlyOwner {
        RANDOMIZER.clientWithdrawTo(msg.sender, amount);
    }
}
