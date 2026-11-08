// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;
import {Test} from "forge-std/Test.sol";
import {TestnetToken} from "../src/TestnetToken.sol";

contract TestnetTokenTest is Test {
    TestnetToken internal token;
    address internal alice = address(0xA11CE);

    function setUp() public {
        vm.chainId(31337);
        token = new TestnetToken("Test A", "B2A");
    }

    function testClaimAndCooldownBoundary() public {
        vm.prank(alice);
        token.claim();
        assertEq(token.balanceOf(alice), 1000 ether);
        uint256 next = token.nextClaimAt(alice);
        vm.expectRevert(abi.encodeWithSelector(TestnetToken.ClaimNotReady.selector, next));
        vm.prank(alice);
        token.claim();
        vm.warp(next - 1);
        vm.expectRevert(abi.encodeWithSelector(TestnetToken.ClaimNotReady.selector, next));
        vm.prank(alice);
        token.claim();
        vm.warp(next);
        vm.prank(alice);
        token.claim();
        assertEq(token.balanceOf(alice), 2000 ether);
    }

    function testSeparateClaimersAndTransfer() public {
        vm.prank(alice);
        token.claim();
        token.claim();
        vm.prank(alice);
        token.transfer(address(this), 10 ether);
        assertEq(token.balanceOf(address(this)), 1010 ether);
        assertEq(token.totalSupply(), 2000 ether);
    }

    function testCapRollsBackClaimTimestamp() public {
        deal(address(token), alice, token.MAX_SUPPLY(), true);
        vm.expectRevert(TestnetToken.FaucetExhausted.selector);
        token.claim();
        assertEq(token.nextClaimAt(address(this)), 0);
    }

    function testMainnetRejected() public {
        vm.chainId(8453);
        vm.expectRevert(abi.encodeWithSelector(TestnetToken.UnsupportedChain.selector, 8453));
        new TestnetToken("No", "NO");
    }

    function testBaseSepoliaAllowed() public {
        vm.chainId(84532);
        TestnetToken other = new TestnetToken("Test B", "B2B");
        other.claim();
        assertEq(other.totalSupply(), 1000 ether);
    }

    function testFuzzClaimBounded(uint32 elapsed) public {
        elapsed = uint32(bound(elapsed, 0, 1 hours - 1));
        token.claim();
        uint256 next = token.nextClaimAt(address(this));
        vm.warp(block.timestamp + elapsed);
        vm.expectRevert(abi.encodeWithSelector(TestnetToken.ClaimNotReady.selector, next));
        token.claim();
        assertLe(token.totalSupply(), token.MAX_SUPPLY());
    }
}
