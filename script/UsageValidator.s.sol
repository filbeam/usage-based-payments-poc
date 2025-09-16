// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {UsageValidator} from "../src/UsageValidator.sol";

contract UsageValidatorScript is Script {
    UsageValidator public usageValidator;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        usageValidator = new UsageValidator();

        vm.stopBroadcast();
    }
}
