// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {FilBeamOperator} from "../src/FilBeamOperator.sol";

contract FilBeamOperatorScript is Script {
    FilBeamOperator public filBeamOperator;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        filBeamOperator = new FilBeamOperator(address(0));

        vm.stopBroadcast();
    }
}
