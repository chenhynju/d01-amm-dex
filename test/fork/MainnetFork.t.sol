// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {Test} from "forge-std/Test.sol";
import {Factory} from "../../src/Factory.sol";
import {Pair} from "../../src/Pair.sol";
import {Router} from "../../src/Router.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MainnetForkTest is Test {
    function testForkRealWETHUSDC() public {
        string memory rpc = vm.envOr("MAINNET_RPC_URL", string(""));
        if (bytes(rpc).length == 0) {
            vm.skip(true);
            return;
        }
        vm.createSelectFork(rpc, 21_000_000);
        address weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        Factory f = new Factory();
        Router r = new Router(f);
        deal(weth, address(this), 100e18);
        deal(usdc, address(this), 300000e6);
        IERC20(weth).approve(address(r), type(uint256).max);
        IERC20(usdc).approve(address(r), type(uint256).max);
        r.addLiquidity(weth, usdc, 10e18, 30000e6, 10e18, 30000e6, address(this), block.timestamp);
        uint256 out = r.swapExactTokensForTokens(weth, usdc, 1e18, 1, address(this), block.timestamp);
        assertGt(out, 0);
        Pair pair = Pair(f.getPair(weth, usdc));
        pair.approve(address(r), pair.balanceOf(address(this)));
        r.removeLiquidity(weth, usdc, pair.balanceOf(address(this)), 1, 1, address(this), block.timestamp);
        assertEq(pair.totalSupply(), 1000);
    }
}
