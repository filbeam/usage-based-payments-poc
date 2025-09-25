// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {FilBeamOperator, IFilecoinWarmStorageService} from "../src/FilBeamOperator.sol";

contract FwssMock is IFilecoinWarmStorageService {
    function settleCDNPaymentRail(uint256 dataSetId, uint256 cdnAmount) external override {}
    function settleCacheMissPaymentRail(uint256 dataSetId, uint256 cacheMissAmount) external override {}
    function terminateCDNPaymentRails(uint256 dataSetId) external override {}
}

contract FilBeamOperatorTest is Test {
    IFilecoinWarmStorageService public fwssMock = new FwssMock();
    FilBeamOperator public filBeamOperator;

    function setUp() public {
        filBeamOperator = new FilBeamOperator(address(fwssMock));
    }

    function testReportRollupUsage() public {
        vm.roll(100);
        uint256 dataSetId = 1;
        uint256[] memory dataSetIds = new uint256[](1);
        uint256[] memory cdnUsages = new uint256[](1);
        uint256[] memory cacheMissUsages = new uint256[](1);

        dataSetIds[0] = dataSetId;
        cdnUsages[0] = 500; // 500 B
        cacheMissUsages[0] = 1024; // 1 KiB

        uint256 currentEpoch = vm.getBlockNumber();
        filBeamOperator.reportRollupUsage(dataSetIds, cdnUsages, cacheMissUsages);

        assertEq(filBeamOperator.cdnUsageByDataSetAndEpoch(dataSetId, currentEpoch - 1), cdnUsages[0]);
        assertEq(filBeamOperator.cacheMissUsageByDataSetAndEpoch(dataSetId, currentEpoch - 1), cacheMissUsages[0]);

        // report same amounts again for on the same epoch
        filBeamOperator.reportRollupUsage(dataSetIds, cdnUsages, cacheMissUsages);
        assertEq(filBeamOperator.cdnUsageByDataSetAndEpoch(dataSetId, currentEpoch - 1), cdnUsages[0] * 2);
        assertEq(filBeamOperator.cacheMissUsageByDataSetAndEpoch(dataSetId, currentEpoch - 1), cacheMissUsages[0] * 2);
    }

    function testSettleCDNPaymentRail() public {
        uint256 dataSetId = 1;

        // data not available
        vm.roll(1);
        filBeamOperator.settleCDNPaymentRail(dataSetId);
        assertEq(filBeamOperator.lastSettledEpoch(dataSetId), 0);

        // Rollup usage for epochs 2 and 4
        uint256[] memory dataSetIds = new uint256[](1);
        uint256[] memory usages = new uint256[](1);
        uint256[] memory cacheMissUsages = new uint256[](1);

        vm.roll(2);
        dataSetIds[0] = dataSetId;
        usages[0] = 1000; // 1000 B
        cacheMissUsages[0] = 500; // 500 B
        filBeamOperator.reportRollupUsage(dataSetIds, usages, cacheMissUsages); // epoch 2

        vm.roll(4);
        usages[0] = 2000; // 2000 B
        cacheMissUsages[0] = 2000; // 2000 B
        filBeamOperator.reportRollupUsage(dataSetIds, usages, cacheMissUsages); // epoch 4

        // settle CDN rail from epoch 1 - 3
        vm.roll(10);
        vm.expectEmit(true, true, true, true);
        emit FilBeamOperator.CDNPaymentSettled(dataSetId, 3, 3000 * filBeamOperator.RATE_PER_BYTE());
        filBeamOperator.settleCDNPaymentRail(dataSetId);
        assertEq(filBeamOperator.lastSettledEpoch(dataSetId), 3);

        // rail wont be settled after epoch 3 because there is no data for epochs 4 - 19
        vm.roll(20);
        filBeamOperator.settleCDNPaymentRail(dataSetId);
        assertEq(filBeamOperator.lastSettledEpoch(dataSetId), 3);
    }

    function testSettleCacheMissPaymentRail() public {
        uint256 dataSetId = 1;

        // data not available
        vm.roll(1);
        filBeamOperator.settleCacheMissPaymentRail(dataSetId);
        assertEq(filBeamOperator.lastSettledEpoch(dataSetId), 0);

        // Rollup usage for epochs 2 and 4
        uint256[] memory dataSetIds = new uint256[](1);
        uint256[] memory usages = new uint256[](1);
        uint256[] memory cacheMissUsages = new uint256[](1);

        vm.roll(2);
        dataSetIds[0] = dataSetId;
        usages[0] = 1000; // 1000 B
        cacheMissUsages[0] = 500; // 500 B
        filBeamOperator.reportRollupUsage(dataSetIds, usages, cacheMissUsages); // epoch 2

        vm.roll(4);
        usages[0] = 2000; // 2000 B
        cacheMissUsages[0] = 2000; // 2000 B
        filBeamOperator.reportRollupUsage(dataSetIds, usages, cacheMissUsages); // epoch 4

        // settle cache-miss rail from epoch 1 - 3
        vm.roll(10);
        vm.expectEmit(true, true, true, true);
        emit FilBeamOperator.CacheMissPaymentSettled(dataSetId, 3, 2500 * filBeamOperator.RATE_PER_BYTE());
        filBeamOperator.settleCacheMissPaymentRail(dataSetId);
        assertEq(filBeamOperator.lastSettledEpoch(dataSetId), 3);

        // rail wont be settled after epoch 3 because there is no data for epochs 4 - 19
        vm.roll(20);
        filBeamOperator.settleCacheMissPaymentRail(dataSetId);
        assertEq(filBeamOperator.lastSettledEpoch(dataSetId), 3);
    }

    function testSettleBothRailsSeparately() public {
        uint256 dataSetId = 1;
        uint256[] memory dataSetIds = new uint256[](1);
        uint256[] memory usages = new uint256[](1);
        uint256[] memory cacheMissUsages = new uint256[](1);

        // Setup usage data
        vm.roll(2);
        dataSetIds[0] = dataSetId;
        usages[0] = 1000; // 1000 B
        cacheMissUsages[0] = 500; // 500 B
        filBeamOperator.reportRollupUsage(dataSetIds, usages, cacheMissUsages);

        vm.roll(10);

        // Settle CDN rail first
        filBeamOperator.settleCDNPaymentRail(dataSetId);
        assertEq(filBeamOperator.lastSettledEpoch(dataSetId), 1); // epoch is now block.number - 1

        // Reset lastSettledEpoch to test cache-miss separately
        vm.store(address(filBeamOperator), keccak256(abi.encode(dataSetId, uint256(21))), bytes32(uint256(0)));

        // Settle cache-miss rail
        filBeamOperator.settleCacheMissPaymentRail(dataSetId);
        assertEq(filBeamOperator.lastSettledEpoch(dataSetId), 1); // epoch is now block.number - 1
    }
}
