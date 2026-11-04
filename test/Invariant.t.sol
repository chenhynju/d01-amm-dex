// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {AMMFixture, MockToken} from "./AMM.t.sol";
import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Pair} from "../src/Pair.sol";
import {Router} from "../src/Router.sol";

/// @notice Stateful actor; ghost ledger tracks underlying assets across swaps/deposits/exits/donations.
contract Handler is Test {
    Pair public p;
    Router public r;
    MockToken public a;
    MockToken public b;
    address public constant SECONDARY = address(0xA11CE);
    uint256 public ghostA;
    uint256 public ghostB;
    uint256 public previousK;
    bool public kViolated;
    uint256 public swaps;
    uint256 public deposits;
    uint256 public exits;
    uint256 public donations;

    constructor(Pair pp, Router rr, MockToken aa, MockToken bb) {
        p = pp;
        r = rr;
        a = aa;
        b = bb;
        ghostA = a.balanceOf(address(p));
        ghostB = b.balanceOf(address(p));
        a.approve(address(r), type(uint256).max);
        b.approve(address(r), type(uint256).max);
        p.approve(address(r), type(uint256).max);
    }

    function swap(uint96 raw, bool reverse) external {
        (uint112 x, uint112 y,) = p.getReserves();
        previousK = uint256(x) * y;
        uint256 n = bound(uint256(raw), 1e6, 1e20);
        MockToken input = reverse ? b : a;
        MockToken output = reverse ? a : b;
        input.mint(address(this), n);
        uint256 out = r.getAmountOut(n, reverse ? y : x, reverse ? x : y);
        if (out == 0) return;
        r.swapExactTokensForTokens(address(input), address(output), n, out, address(this), block.timestamp);
        if (reverse) {
            ghostB += n;
            ghostA -= out;
        } else {
            ghostA += n;
            ghostB -= out;
        }
        (x, y,) = p.getReserves();
        if (uint256(x) * y < previousK) kViolated = true;
        swaps++;
    }

    function deposit(uint96 raw) external {
        uint256 n = bound(uint256(raw), 1e6, 1e20);
        (uint112 x, uint112 y,) = p.getReserves();
        // Supply both desired values using current ratio; router handles floor rounding.
        uint256 m = n * uint256(y) / x + 1;
        uint256 chosenB = n * uint256(y) / x;
        if (chosenB == 0 || n * p.totalSupply() / x == 0 || chosenB * p.totalSupply() / y == 0) return;
        a.mint(address(this), n);
        b.mint(address(this), m);
        (uint256 aa, uint256 bb,) = r.addLiquidity(
            address(a), address(b), n, m, 0, 0, raw % 2 == 0 ? address(this) : SECONDARY, block.timestamp
        );
        ghostA += aa;
        ghostB += bb;
        deposits++;
    }

    function exit(uint256 raw) external {
        address actor = raw % 2 == 0 ? address(this) : SECONDARY;
        uint256 lp = p.balanceOf(actor);
        if (lp == 0) return;
        lp = bound(raw, 1, lp);
        (uint112 x, uint112 y,) = p.getReserves();
        if (lp * uint256(x) / p.totalSupply() == 0 || lp * uint256(y) / p.totalSupply() == 0) return;
        vm.prank(actor);
        p.approve(address(r), lp);
        vm.prank(actor);
        (uint256 aa, uint256 bb) = r.removeLiquidity(address(a), address(b), lp, 0, 0, actor, block.timestamp);
        ghostA -= aa;
        ghostB -= bb;
        exits++;
    }

    function donate(uint64 raw, bool reconcile) external {
        uint256 n = bound(uint256(raw), 1, 1e15);
        a.mint(address(p), n);
        if (reconcile) {
            p.sync();
            ghostA += n;
        } else {
            p.skim(address(this));
        }
        donations++;
    }

    function advance(uint32 dt) external {
        vm.warp(block.timestamp + bound(uint256(dt), 1, 1 days));
        p.sync();
    }
}

contract AMMInvariant is StdInvariant, AMMFixture {
    Handler internal h;

    function setUp() public override {
        super.setUp();
        h = new Handler(p, r, a, b);
        targetContract(address(h));
        bytes4[] memory selectors = new bytes4[](5);
        selectors[0] = h.swap.selector;
        selectors[1] = h.deposit.selector;
        selectors[2] = h.exit.selector;
        selectors[3] = h.donate.selector;
        selectors[4] = h.advance.selector;
        targetSelector(FuzzSelector(address(h), selectors));
    }

    function invariant_feeAdjustedKDoesNotDecreaseOnSwap() public view {
        assertFalse(h.kViolated());
    }

    function invariant_ghostAssetConservation() public view {
        assertEq(a.balanceOf(address(p)), h.ghostA());
        assertEq(b.balanceOf(address(p)), h.ghostB());
    }

    function invariant_reservesMatchBalances() public view {
        (uint112 x, uint112 y,) = p.getReserves();
        assertEq(x, a.balanceOf(address(p)));
        assertEq(y, b.balanceOf(address(p)));
    }

    function invariant_supplyEqualsTrackedHolders() public view {
        assertEq(
            p.totalSupply(),
            p.balanceOf(address(this)) + p.balanceOf(address(h)) + p.balanceOf(h.SECONDARY()) + p.balanceOf(address(1))
        );
    }

    function invariant_lockedLiquidity() public view {
        assertEq(p.balanceOf(address(1)), 1000);
        assertGe(p.totalSupply(), 1000);
    }

    function invariant_claimsAreSolvent() public view {
        (uint112 x, uint112 y,) = p.getReserves();
        uint256 s = p.totalSupply();
        uint256 lp = p.balanceOf(address(h)) + p.balanceOf(h.SECONDARY()) + p.balanceOf(address(this));
        assertLe(lp * uint256(x) / s, x);
        assertLe(lp * uint256(y) / s, y);
    }

    function invariant_quoteMonotonicAndBounded() public view {
        (uint112 x, uint112 y,) = p.getReserves();
        assertLe(r.getAmountOut(1e12, x, y), r.getAmountOut(2e12, x, y));
        assertLt(r.getAmountOut(2e12, x, y), y);
    }

    function afterInvariant() public {
        _exitActor(address(h));
        _exitActor(h.SECONDARY());
    }

    function _exitActor(address actor) private {
        uint256 lp = p.balanceOf(actor);
        if (lp > 0) {
            (uint112 x, uint112 y,) = p.getReserves();
            bool dust = lp * uint256(x) / p.totalSupply() == 0 || lp * uint256(y) / p.totalSupply() == 0;
            vm.prank(actor);
            p.approve(address(r), lp);
            if (dust) vm.expectRevert(Pair.InsufficientLiquidity.selector);
            vm.prank(actor);
            r.removeLiquidity(address(a), address(b), lp, 0, 0, actor, block.timestamp);
            assertEq(p.balanceOf(actor), dust ? lp : 0);
        }
    }
}
