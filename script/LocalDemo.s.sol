// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {Script} from "forge-std/Script.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Factory} from "../src/Factory.sol";
import {Router} from "../src/Router.sol";
import {Pair} from "../src/Pair.sol";

/// @notice Unrestricted demo supply, exclusively for local Anvil smoke tests; not a production token.
contract DemoToken is ERC20 {
    constructor(string memory symbol) ERC20(symbol, symbol) {
        _mint(msg.sender, 1e24);
    }
}

contract LocalDemo is Script {
    function run() external {
        require(block.chainid == 31337, "local only");
        vm.startBroadcast();
        Factory f = new Factory();
        Router r = new Router(f);
        DemoToken a = new DemoToken("DEMO-A");
        DemoToken b = new DemoToken("DEMO-B");
        a.approve(address(r), type(uint256).max);
        b.approve(address(r), type(uint256).max);
        r.addLiquidity(address(a), address(b), 1e18, 1e18, 1e18, 1e18, msg.sender, block.timestamp + 1 hours);
        r.swapExactTokensForTokens(address(a), address(b), 1e16, 9e15, address(0xB0B), block.timestamp + 1 hours);
        Pair pair = Pair(f.getPair(address(a), address(b)));
        uint256 lp = pair.balanceOf(msg.sender);
        pair.approve(address(r), lp);
        r.removeLiquidity(address(a), address(b), lp, 1, 1, msg.sender, block.timestamp + 1 hours);
        vm.stopBroadcast();
    }
}
