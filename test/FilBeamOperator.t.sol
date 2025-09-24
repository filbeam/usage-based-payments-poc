// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {FilBeamOperator, IFilecoinWarmStorageService} from "../src/FilBeamOperator.sol";

contract FwssMock is IFilecoinWarmStorageService {
    function settleCDNPaymentRails(uint256 dataSetId, uint256 cdnAmount, uint256 cacheMissAmount) external override {}
    function terminateCDNPaymentRails(uint256 dataSetId) external override {}
}

contract FilBeamOperatorTest is Test {
    IFilecoinWarmStorageService public fwssMock = new FwssMock();
    FilBeamOperator public filBeamOperator;

    function setUp() public {
        filBeamOperator = new FilBeamOperator(address(fwssMock));
    }

    function testReportRollupUsage() public {
        uint256 dataSetId = 1;
        uint256[] memory dataSetIds = new uint256[](1);
        uint256[] memory cdnUsages = new uint256[](1);
        uint256[] memory cacheMissUsages = new uint256[](1);

        dataSetIds[0] = dataSetId;
        cdnUsages[0] = 500; // 500 B
        cacheMissUsages[0] = 1024; // 1 KiB

        uint256 currentEpoch = vm.getBlockNumber();
        filBeamOperator.reportRollupUsage(dataSetIds, cdnUsages, cacheMissUsages);

        assertEq(filBeamOperator.cdnUsageByDataSetAndEpoch(dataSetId, currentEpoch), cdnUsages[0]);
        assertEq(filBeamOperator.cacheMissUsageByDataSetAndEpoch(dataSetId, currentEpoch), cacheMissUsages[0]);
    }

    function testSettleCDNPaymentRails() public {
        uint256 dataSetId = 1;

        // data not available
        vm.roll(1);
        filBeamOperator.settleCDNPaymentRails(dataSetId);
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

        // settle from epoch 1 - 4
        vm.roll(10);
        vm.expectEmit(true, true, true, true);
        emit FilBeamOperator.CDNPaymentSettled(
            dataSetId, 4, 3000 * filBeamOperator.RATE_PER_BYTE(), 2500 * filBeamOperator.RATE_PER_BYTE()
        );
        filBeamOperator.settleCDNPaymentRails(dataSetId);
        assertEq(filBeamOperator.lastSettledEpoch(dataSetId), 4);

        // rail wont be settled after epoch 4 because there is no data for epochs 4 - 20
        vm.roll(20);
        filBeamOperator.settleCDNPaymentRails(dataSetId);
        assertEq(filBeamOperator.lastSettledEpoch(dataSetId), 4);
    }
}
