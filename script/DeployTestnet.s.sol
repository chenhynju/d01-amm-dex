// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;
import {Script} from "forge-std/Script.sol";
import {Factory} from "../src/Factory.sol";
import {Router} from "../src/Router.sol";
import {Pair} from "../src/Pair.sol";
import {TestnetToken} from "../src/TestnetToken.sol";

/// @notice Bootstrap a public testnet exchange using only synthetic faucet assets.
/// @dev Mainnet is rejected. External keystore/signer configuration supplies authorization.
contract DeployTestnet is Script {
    error UnsupportedChain(uint256 chainId);

    function run() external returns (Factory f, Router r, TestnetToken a, TestnetToken b, Pair pair) {
        if (block.chainid != 31337 && block.chainid != 84532) revert UnsupportedChain(block.chainid);
        address deployer = vm.envAddress("DEPLOYER_ADDRESS");
        vm.startBroadcast(deployer);
        f = new Factory();
        r = new Router(f);
        a = new TestnetToken("B2 Test Token A", "B2A");
        b = new TestnetToken("B2 Test Token B", "B2B");
        a.claim();
        b.claim();
        a.approve(address(r), 100 ether);
        b.approve(address(r), 100 ether);
        r.addLiquidity(
            address(a), address(b), 100 ether, 100 ether, 100 ether, 100 ether, deployer, block.timestamp + 20 minutes
        );
        pair = Pair(f.getPair(address(a), address(b)));
        vm.stopBroadcast();
    }
}
