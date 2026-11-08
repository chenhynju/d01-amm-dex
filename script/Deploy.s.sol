// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;
import {Script} from "forge-std/Script.sol";
import {Factory} from "../src/Factory.sol";
import {Router} from "../src/Router.sol";

/// @notice Uses Foundry's external signer configuration; never reads a raw private key from source.
contract Deploy is Script {
    function run() external returns (Factory f, Router r) {
        vm.startBroadcast();
        f = new Factory();
        r = new Router(f);
        vm.stopBroadcast();
    }
}
