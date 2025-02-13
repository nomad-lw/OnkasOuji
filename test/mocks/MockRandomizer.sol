// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.26;

import {IRandomizer} from "../../src/interfaces/ext/IRandomizer.sol";

contract MockRandomizer is IRandomizer {
    uint256 private constant CALLBACK_GAS = 100_000;
    mapping(address => uint256) private deposits;
    mapping(address => uint256) private reserved;

    function estimateFee(uint256 callbackGasLimit) external pure returns (uint256) {
        return callbackGasLimit * 50 gwei;
    }

    // Implementation of other interface methods...
}
