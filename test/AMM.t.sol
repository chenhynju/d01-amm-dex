// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Pair, IFlashCallee} from "../src/Pair.sol";
import {Factory} from "../src/Factory.sol";
import {Router} from "../src/Router.sol";

contract MockToken is ERC20 {
    bool public taxed;
    bool public fail;
    constructor(string memory n) ERC20(n, n) {}

    function mint(address to, uint256 n) external {
        _mint(to, n);
    }

    function confiscate(address from, uint256 n) external {
        _burn(from, n);
    }

    function setTax(bool v) external {
        taxed = v;
    }

    function setFail(bool v) external {
        fail = v;
    }

    function _update(address from, address to, uint256 n) internal virtual override {
        require(!fail, "token failure");
        if (taxed && from != address(0) && to != address(0)) {
            uint256 fee = n / 100;
            super._update(from, address(0), fee);
            super._update(from, to, n - fee);
        } else {
            super._update(from, to, n);
        }
    }
}

// USDT-style successful calls return no bytes.
contract NoReturnToken {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 n) external {
        balanceOf[to] += n;
    }

    function approve(address to, uint256 n) external {
        allowance[msg.sender][to] = n;
    }

    function transfer(address to, uint256 n) external {
        balanceOf[msg.sender] -= n;
        balanceOf[to] += n;
    }

    function transferFrom(address from, address to, uint256 n) external {
        allowance[from][msg.sender] -= n;
        balanceOf[from] -= n;
        balanceOf[to] += n;
    }
}

contract FlashActor is IFlashCallee {
    Pair public pair;
    MockToken public token;
    uint256 public mode;
    bool public readBlocked;
    bool public writeBlocked;

    constructor(Pair p, MockToken t) {
        pair = p;
        token = t;
    }

    function run(uint256 n, uint256 m) external {
        mode = m;
        pair.swap(n, 0, address(this), hex"01");
    }

    function ammCall(address, uint256 n, uint256, bytes calldata) external {
        require(msg.sender == address(pair));
        if (mode == 1) return;
        (bool ok,) = address(pair).staticcall(abi.encodeCall(pair.getReserves, ()));
        readBlocked = !ok;
        (ok,) = address(pair).call(abi.encodeCall(pair.sync, ()));
        writeBlocked = !ok;
        // ceil(n*1000/997): repayment includes rounded-up fee.
        token.transfer(address(pair), (n * 1000 + 996) / 997);
    }
}

contract HookToken is MockToken {
    address public routerTarget;
    address public pool;
    bool public routerBlocked;
    bool public reserveReadBlocked;
    constructor() MockToken("HOOK") {}

    function configure(address rr, address pp) external {
        routerTarget = rr;
        pool = pp;
    }

    function _update(address from, address to, uint256 n) internal override {
        super._update(from, to, n);
        if (from == pool && pool != address(0)) {
            (bool ok,) = routerTarget.call(
                abi.encodeWithSelector(
                    Router.swapExactTokensForTokens.selector, address(this), address(this), 1, 0, to, block.timestamp
                )
            );
            routerBlocked = !ok;
            (ok,) = pool.staticcall(abi.encodeWithSelector(Pair.getReserves.selector));
            reserveReadBlocked = !ok;
        }
    }
}

abstract contract AMMFixture is Test {
    Factory internal f;
    Router internal r;
    Pair internal p;
    MockToken internal a;
    MockToken internal b;
    address internal bob = address(0xB0B);

    function setUp() public virtual {
        f = new Factory();
        r = new Router(f);
        MockToken x = new MockToken("A");
        MockToken y = new MockToken("B");
        (a, b) = address(x) < address(y) ? (x, y) : (y, x);
        p = Pair(f.createPair(address(a), address(b)));
        a.mint(address(this), 1e30);
        b.mint(address(this), 1e30);
        a.approve(address(r), type(uint256).max);
        b.approve(address(r), type(uint256).max);
        r.addLiquidity(address(a), address(b), 1e18, 1e18, 1e18, 1e18, address(this), block.timestamp);
    }
}

contract AMMTest is AMMFixture {
    function testFactory() public {
        assertEq(f.getPair(address(b), address(a)), address(p));
        assertEq(f.allPairsLength(), 1);
        assertEq(f.allPairs(0), address(p));
        vm.expectRevert(Factory.PairExists.selector);
        f.createPair(address(b), address(a));
        vm.expectRevert(Factory.InvalidTokens.selector);
        f.createPair(address(a), address(a));
        vm.expectRevert(Factory.InvalidTokens.selector);
        f.createPair(address(0), address(a));
        vm.expectRevert(Factory.InvalidTokens.selector);
        f.createPair(address(42), address(a));
    }

    function testSwapAndFee() public {
        uint256 out = r.getAmountOut(1e16, 1e18, 1e18);
        uint256 got = r.swapExactTokensForTokens(address(a), address(b), 1e16, out, bob, block.timestamp);
        assertEq(got, out);
        assertEq(b.balanceOf(bob), out);
        (uint112 x, uint112 y,) = p.getReserves();
        assertGe(uint256(x) * y, 1e36);
        assertGe((uint256(x) * 1000 - 1e16 * 3) * uint256(y) * 1000, 1e42);
    }

    function testReverseSwap() public {
        uint256 out = r.getAmountOut(1e16, 1e18, 1e18);
        assertEq(r.swapExactTokensForTokens(address(b), address(a), 1e16, out, bob, block.timestamp), out);
    }

    function testBurnAllUserLP() public {
        uint256 lp = p.balanceOf(address(this));
        p.approve(address(r), lp);
        (uint256 x, uint256 y) = r.removeLiquidity(address(a), address(b), lp, 1, 1, bob, block.timestamp);
        assertEq(x, 1e18 - 1000);
        assertEq(y, 1e18 - 1000);
        assertEq(p.totalSupply(), 1000);
        assertEq(p.balanceOf(address(1)), 1000);
    }

    function testSkimAndSync() public {
        a.transfer(address(p), 100);
        p.skim(bob);
        assertEq(a.balanceOf(bob), 100);
        a.transfer(address(p), 200);
        p.sync();
        (uint112 x,,) = p.getReserves();
        assertEq(x, 1e18 + 200);
        p.skim(bob);
        assertEq(a.balanceOf(bob), 100);
    }

    function testTWAPAndTimestampWrap() public {
        (uint256 q0,, uint32 t) = p.currentCumulativePrices();
        vm.warp(block.timestamp + 20);
        (uint256 q1,,) = p.currentCumulativePrices();
        assertEq(q1 - q0, uint256(1 << 112) * 20);
        p.sync();
        assertEq(p.price0CumulativeLast(), q1);
        vm.warp(uint256(type(uint32).max) + 10);
        p.sync();
        (,, uint32 t2) = p.getReserves();
        assertEq(t2, 9);
        assertGt(t2, t);
    }

    function testFlashRepaymentAndLocks() public {
        FlashActor actor = new FlashActor(p, a);
        a.mint(address(actor), 1e18);
        actor.run(1e15, 0);
        assertTrue(actor.readBlocked());
        assertTrue(actor.writeBlocked());
    }

    function testFlashNoRepay() public {
        FlashActor actor = new FlashActor(p, a);
        vm.expectRevert(Pair.InsufficientInput.selector);
        actor.run(1e15, 1);
    }

    function testTaxedSwapBothDirections() public {
        a.setTax(true);
        b.setTax(true);
        uint256 expected = r.getAmountOut(1e16 - 1e14, 1e18, 1e18);
        expected -= expected / 100;
        assertEq(r.swapExactTokensForTokens(address(a), address(b), 1e16, expected, bob, block.timestamp), expected);
    }

    function testTaxedDepositReverts() public {
        a.setTax(true);
        vm.expectRevert(Router.UnsupportedTransfer.selector);
        r.addLiquidity(address(a), address(b), 1e16, 1e16, 0, 0, bob, block.timestamp);
    }

    function testRemoveTaxedMinimum() public {
        p.approve(address(r), 1e16);
        a.setTax(true);
        vm.expectRevert(Router.Slippage.selector);
        r.removeLiquidity(address(a), address(b), 1e16, 1e16, 0, bob, block.timestamp);
        (uint256 x,) = r.removeLiquidity(address(a), address(b), 1e16, 99e14, 0, bob, block.timestamp);
        assertEq(x, 99e14);
    }

    function testNoReturnToken() public {
        NoReturnToken t = new NoReturnToken();
        t.mint(address(this), 1e20);
        t.approve(address(r), 1e20);
        r.addLiquidity(address(t), address(b), 1e18, 1e18, 0, 0, address(this), block.timestamp);
        assertGt(r.swapExactTokensForTokens(address(t), address(b), 1e16, 1, bob, block.timestamp), 0);
    }

    function testSlippageDeadlineRollback() public {
        vm.expectRevert(Router.Slippage.selector);
        r.swapExactTokensForTokens(address(a), address(b), 1e16, 1e18, bob, block.timestamp);
        (uint112 x, uint112 y,) = p.getReserves();
        assertEq(x, y);
        vm.expectRevert(Router.Expired.selector);
        r.swapExactTokensForTokens(address(a), address(b), 1, 0, bob, block.timestamp - 1);
    }

    function testNegativeRebaseRecovery() public {
        a.confiscate(address(p), 1e17);
        vm.expectRevert();
        p.skim(bob);
        p.sync();
        (uint112 x,,) = p.getReserves();
        assertEq(x, 9e17);
    }

    function testReserveOverflow() public {
        a.mint(address(p), type(uint112).max);
        vm.expectRevert(Pair.Overflow.selector);
        p.sync();
    }

    function testInvalidSwap() public {
        vm.expectRevert(Pair.InsufficientLiquidity.selector);
        p.swap(0, 0, bob, "");
        vm.expectRevert(Pair.InsufficientLiquidity.selector);
        p.swap(1e18, 0, bob, "");
        vm.expectRevert(Pair.InvalidRecipient.selector);
        p.swap(1, 0, address(a), "");
        vm.expectRevert(Pair.InsufficientInput.selector);
        p.swap(1, 0, bob, "");
        a.transfer(address(p), 1);
        vm.expectRevert(Pair.InvariantViolation.selector);
        p.swap(0, 1e17, bob, "");
    }

    function testInvalidRouter() public {
        vm.expectRevert(Router.InvalidRecipient.selector);
        r.swapExactTokensForTokens(address(a), address(b), 1, 0, address(r), block.timestamp);
        vm.expectRevert(Router.MissingPair.selector);
        r.swapExactTokensForTokens(address(a), address(77), 1, 0, bob, block.timestamp);
        vm.expectRevert(Router.InvalidAmount.selector);
        r.getAmountOut(0, 1, 1);
        vm.expectRevert(Router.InvalidRecipient.selector);
        r.swapExactTokensForTokens(address(a), address(b), 1, 0, address(p), block.timestamp);
    }

    function testTokenFailureAtomic() public {
        a.setFail(true);
        vm.expectRevert("token failure");
        r.swapExactTokensForTokens(address(a), address(b), 1e16, 0, bob, block.timestamp);
    }

    function testDonationNotOwned() public {
        a.transfer(address(p), 1e16);
        p.skim(bob);
        assertEq(a.balanceOf(bob), 1e16);
    }

    function testProportionalDepositAndSlippage() public {
        (uint256 x, uint256 y, uint256 lp) =
            r.addLiquidity(address(a), address(b), 2e16, 1e16, 1e16, 1e16, bob, block.timestamp);
        assertEq(x, 1e16);
        assertEq(y, 1e16);
        assertEq(lp, 1e16);
        vm.expectRevert(Router.Slippage.selector);
        r.addLiquidity(address(a), address(b), 1e16, 2e16, 1e16, 2e16, bob, block.timestamp);
    }

    function testPermitReplay() public {
        uint256 key = 1234;
        address signer = vm.addr(key);
        bytes32 typehash =
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
        uint256 deadline = block.timestamp + 100;
        bytes32 digest = keccak256(
            abi.encodePacked(
                hex"1901", p.DOMAIN_SEPARATOR(), keccak256(abi.encode(typehash, signer, address(r), 1e18, 0, deadline))
            )
        );
        (uint8 v, bytes32 rr, bytes32 s) = vm.sign(key, digest);
        p.permit(signer, address(r), 1e18, deadline, v, rr, s);
        assertEq(p.allowance(signer, address(r)), 1e18);
        vm.expectRevert();
        p.permit(signer, address(r), 1e18, deadline, v, rr, s);
    }

    function testTokenHookRouterAndReadLocks() public {
        HookToken t = new HookToken();
        t.mint(address(this), 1e20);
        t.approve(address(r), type(uint256).max);
        r.addLiquidity(address(a), address(t), 1e18, 1e18, 0, 0, address(this), block.timestamp);
        t.configure(address(r), f.getPair(address(a), address(t)));
        r.swapExactTokensForTokens(address(a), address(t), 1e16, 1, bob, block.timestamp);
        assertTrue(t.routerBlocked());
        assertTrue(t.reserveReadBlocked());
    }

    function testDustLPExitIsAtomic() public {
        r.swapExactTokensForTokens(address(a), address(b), 1e20, 0, bob, block.timestamp);
        p.transfer(bob, 1);
        vm.prank(bob);
        p.approve(address(r), 1);
        vm.expectRevert(Pair.InsufficientLiquidity.selector);
        vm.prank(bob);
        r.removeLiquidity(address(a), address(b), 1, 0, 0, bob, block.timestamp);
        assertEq(p.balanceOf(bob), 1);
        assertEq(p.balanceOf(address(p)), 0);
    }

    function testEmptyPoolAndMintBoundaries() public {
        Pair empty = new Pair(address(a), address(b));
        (uint256 q0, uint256 q1,) = empty.currentCumulativePrices();
        assertEq(q0, 0);
        assertEq(q1, 0);
        empty.sync();
        vm.expectRevert(Pair.InsufficientLiquidity.selector);
        empty.mint(bob);
        a.transfer(address(empty), 1000);
        b.transfer(address(empty), 1000);
        vm.expectRevert(Pair.InsufficientLiquidity.selector);
        empty.mint(bob);
        a.transfer(address(empty), 1);
        b.transfer(address(empty), 1);
        assertEq(empty.mint(bob), 1);
        vm.expectRevert(Pair.InsufficientLiquidity.selector);
        empty.mint(bob);
        vm.expectRevert(Pair.InsufficientLiquidity.selector);
        empty.burn(bob);
        vm.expectRevert(Pair.InvalidRecipient.selector);
        empty.mint(address(0));
    }

    function testPairConstructorValidation() public {
        vm.expectRevert(Pair.InvalidTokens.selector);
        new Pair(address(b), address(a));
        vm.expectRevert(Pair.InvalidTokens.selector);
        new Pair(address(0), address(a));
        vm.expectRevert(Pair.InvalidTokens.selector);
        new Pair(address(42), address(a));
    }

    function testRouterAmountBounds() public {
        vm.expectRevert(Router.InvalidAmount.selector);
        r.getAmountOut(uint256(type(uint112).max) + 1, 1, 1);
        vm.expectRevert(Router.InvalidAmount.selector);
        r.getAmountOut(1, 0, 1);
        vm.expectRevert(Router.InvalidAmount.selector);
        r.getAmountOut(1, 1, 0);
        vm.expectRevert(Router.InvalidAmount.selector);
        r.getAmountOut(1, uint256(type(uint112).max) + 1, 1);
        vm.expectRevert(Router.InvalidAmount.selector);
        r.getAmountOut(1, 1, uint256(type(uint112).max) + 1);
        vm.expectRevert(Router.InvalidAmount.selector);
        r.addLiquidity(address(a), address(b), 0, 0, 0, 0, bob, block.timestamp);
    }

    function testRouterCreatesPairAndReverseAdd() public {
        MockToken t = new MockToken("NEW");
        t.mint(address(this), 1e20);
        t.approve(address(r), type(uint256).max);
        r.addLiquidity(address(t), address(a), 1e18, 1e18, 0, 0, bob, block.timestamp);
        assertTrue(f.getPair(address(t), address(a)) != address(0));
        (uint256 x, uint256 y,) = r.addLiquidity(address(b), address(a), 1e16, 2e16, 0, 0, bob, block.timestamp);
        assertEq(x, 1e16);
        assertEq(y, 1e16);
    }

    function testOneSidedSyncedPoolRejected() public {
        MockToken t = new MockToken("ONE");
        Pair one = Pair(f.createPair(address(a), address(t)));
        a.transfer(address(one), 1e18);
        one.sync();
        t.mint(address(this), 1e20);
        t.approve(address(r), type(uint256).max);
        vm.expectRevert(Router.InvalidAmount.selector);
        r.addLiquidity(address(a), address(t), 1e18, 1e18, 0, 0, bob, block.timestamp);
    }

    function testMaximumReserves() public {
        Pair other = new Pair(address(a), address(b));
        a.mint(address(other), type(uint112).max);
        b.mint(address(other), type(uint112).max);
        other.mint(bob);
        (uint112 x, uint112 y,) = other.getReserves();
        assertEq(x, type(uint112).max);
        assertEq(x, y);
        assertEq(other.totalSupply(), type(uint112).max);
    }

    function testInvalidRecipients() public {
        vm.expectRevert(Pair.InvalidRecipient.selector);
        p.skim(address(p));
        vm.expectRevert(Pair.InvalidRecipient.selector);
        p.burn(address(1));
        vm.expectRevert(Pair.InvalidRecipient.selector);
        p.swap(1, 0, address(b), "");
        vm.expectRevert(Router.InvalidRecipient.selector);
        r.addLiquidity(address(a), address(b), 1, 1, 0, 0, address(0), block.timestamp);
        vm.expectRevert(Router.InvalidRecipient.selector);
        r.removeLiquidity(address(a), address(b), 1, 0, 0, address(1), block.timestamp);
    }

    function testFuzzSwap(uint96 raw, bool reverse) public {
        uint256 n = bound(uint256(raw), 1e6, 1e23);
        (MockToken input, MockToken output) = reverse ? (b, a) : (a, b);
        uint256 out = r.getAmountOut(n, 1e18, 1e18);
        assertEq(r.swapExactTokensForTokens(address(input), address(output), n, out, bob, block.timestamp), out);
        (uint112 x, uint112 y,) = p.getReserves();
        assertGe(uint256(x) * y, 1e36);
    }

    function testFuzzQuoteMonotonic(uint112 x, uint112 y, uint96 n) public view {
        uint256 ri = bound(uint256(x), 1, type(uint112).max);
        uint256 ro = bound(uint256(y), 1, type(uint112).max);
        uint256 input = bound(uint256(n), 1, type(uint96).max - 1);
        uint256 out = r.getAmountOut(input, ri, ro);
        assertLe(out, r.getAmountOut(input + 1, ri, ro));
        assertLt(out, ro);
        assertGe((ri * 1000 + input * 997) * (ro - out), ri * ro * 1000);
    }

    function testFuzzLPExit(uint96 raw) public {
        uint256 n = bound(uint256(raw), 1001, 1e23);
        (,, uint256 lp) = r.addLiquidity(address(a), address(b), n, n, n, n, bob, block.timestamp);
        vm.startPrank(bob);
        p.approve(address(r), lp);
        (uint256 x, uint256 y) = r.removeLiquidity(address(a), address(b), lp, 0, 0, bob, block.timestamp);
        vm.stopPrank();
        assertEq(x, n);
        assertEq(y, n);
    }
}
