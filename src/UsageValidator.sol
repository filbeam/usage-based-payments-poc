// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IValidator} from "@filecoin-pay/Payments.sol";

contract UsageValidator is IValidator {
    uint256 private constant MIB_IN_BYTES = 1024 * 1024; // 1 MiB in bytes
    uint256 private constant DEFAULT_LOCKUP_PERIOD = 2880 * 10; // 10 days in epochs
    uint256 private constant GIB_IN_BYTES = MIB_IN_BYTES * 1024; // 1 GiB in bytes
    uint256 private constant TIB_IN_BYTES = GIB_IN_BYTES * 1024; // 1 TiB in bytes
    uint256 public constant RATE_PER_TIB = 10e6; // $10, scaled to 6 decimals

    // Constant rate for all rails
    uint256 public constant RATE = RATE_PER_TIB / TIB_IN_BYTES;

    // usageByRailAndEpoch[railId][epoch] = usage
    mapping(bytes32 => mapping(uint256 => uint256)) public usageByRailAndEpoch;
    // lastSettledEpoch[railId] = last epoch settled
    mapping(bytes32 => uint256) public lastSettledEpoch;

    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not contract owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    // Rollup usage for multiple rails, assigns current epoch
    function rollupUsage(uint256[] calldata railIds, uint256[] calldata usages) external onlyOwner {
        uint256 epoch = block.number;
        for (uint256 i = 0; i < railIds.length; i++) {
            usageByRailAndEpoch[_railKey(railIds[i])][epoch] = usages[i];
        }
    }

    function validatePayment(
        uint256 railId,
        uint256, /*proposedAmount*/
        uint256 fromEpoch,
        uint256 toEpoch,
        uint256 /*rate*/
    ) external override returns (ValidationResult memory result) {
        bytes32 key = _railKey(railId);
        uint256 sum = 0;
        uint256 lastEpochWithData = fromEpoch - 1;
        bool foundData = false;

        for (uint256 epoch = fromEpoch; epoch <= toEpoch; epoch++) {
            uint256 usage = usageByRailAndEpoch[key][epoch];
            if (usage > 0) {
                sum += usage * RATE;
                lastEpochWithData = epoch;
                foundData = true;
            }
        }

        if (!foundData) {
            // No data available for requested period, return previous settleUpto
            result = ValidationResult({
                modifiedAmount: 0,
                settleUpto: lastSettledEpoch[key],
                note: "No usage data available for requested period"
            });
        } else {
            // Data available up to lastEpochWithData
            result = ValidationResult({
                modifiedAmount: sum,
                settleUpto: lastEpochWithData,
                note: "Settled up to available data"
            });
            lastSettledEpoch[key] = lastEpochWithData;
        }
    }

    function railTerminated(uint256, /*railId*/ address, /*terminator*/ uint256 /*endEpoch*/ ) external override {}

    // Helper to convert uint256 railId to bytes32
    function _railKey(uint256 railId) internal pure returns (bytes32) {
        return bytes32(railId);
    }
}
