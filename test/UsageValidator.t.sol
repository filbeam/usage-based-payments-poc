// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {UsageValidator} from "../src/UsageValidator.sol";
import {IValidator} from "@filecoin-pay/Payments.sol";

contract UsageValidatorTest is Test {
    UsageValidator public usageValidator;

    function setUp() public {
        usageValidator = new UsageValidator();
    }

    function testRollupUsage() public {
        uint256[] memory railIds = new uint256[](2);
        uint256[] memory usages = new uint256[](2);

        railIds[0] = 1;
        usages[0] = 500; // 500 B
        railIds[1] = 2;
        usages[1] = 1024; // 1 KiB

        uint256 currentEpoch = vm.getBlockNumber();
        usageValidator.rollupUsage(railIds, usages);

        assertEq(usageValidator.usageByRailAndEpoch(bytes32(railIds[0]), currentEpoch), usages[0]);
        assertEq(usageValidator.usageByRailAndEpoch(bytes32(railIds[1]), currentEpoch), usages[1]);
    }

    function testValidatePayment_noDataAvailable() public {
        uint256 railId = 1;
        uint256 fromEpoch = 1;
        uint256 toEpoch = 5;

        IValidator.ValidationResult memory result = usageValidator.validatePayment(railId, 0, fromEpoch, toEpoch, 0);

        assertEq(result.modifiedAmount, 0);
        assertEq(result.settleUpto, 0);
        assertEq(result.note, "No usage data available for requested period");
        assertEq(usageValidator.lastSettledEpoch(bytes32(railId)), 0);
    }

    function testValidatePayment_startHigherThenMaximumAvailableEpoch() public {
        uint256 railId = 1;
        uint256 fromEpoch = 5;
        uint256 toEpoch = 10;

        // Rollup usage for epochs 2 and 4
        uint256[] memory railIds = new uint256[](1);
        uint256[] memory usages = new uint256[](1);

        vm.roll(2);
        railIds[0] = railId;
        usages[0] = 1000; // 1000 B
        usageValidator.rollupUsage(railIds, usages); // epoch 2

        vm.roll(4);
        usages[0] = 2000; // 2000 B
        usageValidator.rollupUsage(railIds, usages); // epoch 4

        IValidator.ValidationResult memory result = usageValidator.validatePayment(railId, 0, fromEpoch, toEpoch, 0);

        assertEq(result.modifiedAmount, 0);
        assertEq(result.settleUpto, 0);
        assertEq(result.note, "No usage data available for requested period");
        assertEq(usageValidator.lastSettledEpoch(bytes32(railId)), 0);
    }

    function testValidatePayment_dataPartiallyAvailable() public {
        uint256 railId = 1;
        uint256 fromEpoch = 1;
        uint256 toEpoch = 5;

        // Rollup usage for epochs 2 and 4
        uint256[] memory railIds = new uint256[](2);
        uint256[] memory usages = new uint256[](2);

        vm.roll(1);
        railIds[0] = railId;
        usages[0] = 1000; // 1000 B
        usageValidator.rollupUsage(railIds, usages); // epoch 1

        vm.roll(2);
        usages[0] = 2000; // 2000 B
        usageValidator.rollupUsage(railIds, usages); // epoch 2

        vm.roll(3);
        // No usage for epoch 3

        vm.roll(4);
        usages[0] = 1500; // 1500 B
        usageValidator.rollupUsage(railIds, usages); // epoch 4

        IValidator.ValidationResult memory result = usageValidator.validatePayment(railId, 0, fromEpoch, toEpoch, 0);

        // Expected sum: (2000 * RATE) + (1500 * RATE) = (2000 + 1500) * RATE
        uint256 expectedSum = 3500 * usageValidator.RATE();
        assertEq(result.modifiedAmount, expectedSum);
        assertEq(result.settleUpto, 4);
        assertEq(result.note, "Settled up to available data");
        assertEq(usageValidator.lastSettledEpoch(bytes32(railId)), 4);
    }

    function testValidatePayment_requestedSettlementPeriodSmallerThenAvailableData() public {
        uint256 railId = 1;
        uint256 fromEpoch = 1;
        uint256 toEpoch = 5;

        // Rollup usage for epochs 2 and 4
        uint256[] memory railIds = new uint256[](1);
        uint256[] memory usages = new uint256[](1);

        vm.roll(1);
        railIds[0] = railId;
        usages[0] = 1000; // 1000 B
        usageValidator.rollupUsage(railIds, usages); // epoch 1

        vm.roll(5);
        usages[0] = 2000; // 2000 B
        usageValidator.rollupUsage(railIds, usages); // epoch 5

        vm.roll(10);
        usages[0] = 0; // 0 B
        usageValidator.rollupUsage(railIds, usages); // epoch 10

        vm.roll(15);
        usages[0] = 1500; // 1500 B
        usageValidator.rollupUsage(railIds, usages); // epoch 15

        IValidator.ValidationResult memory result = usageValidator.validatePayment(railId, 0, fromEpoch, toEpoch, 0);

        // Expected sum: (1000 * RATE) + (2000 * RATE) = (1000 + 2000) * RATE
        uint256 expectedSum = 3000 * usageValidator.RATE();
        assertEq(result.modifiedAmount, expectedSum);
        assertEq(result.settleUpto, 5);
        assertEq(result.note, "Settled up to available data");
        assertEq(usageValidator.lastSettledEpoch(bytes32(railId)), 5);
    }
}
