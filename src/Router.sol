// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {Factory} from "./Factory.sol";
import {Pair} from "./Pair.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title Atomic ERC20-only AMM entrypoint
/// @notice Single-hop exact-input swaps; output minimum checks actual recipient balance delta.
contract Router is ReentrancyGuard {
    using SafeERC20 for IERC20;
    error Expired();
    error Slippage();
    error InvalidAmount();
    error InvalidRecipient();
    error MissingPair();
    error UnsupportedTransfer();
    Factory public immutable factory;

    constructor(Factory f) {
        factory = f;
    }

    modifier timely(uint256 deadline) {
        if (block.timestamp > deadline) revert Expired();
        _;
    }

    /// @notice Floor-rounded output in raw token units, after 30 bps fee.
    function getAmountOut(uint256 input, uint256 rIn, uint256 rOut) public pure returns (uint256) {
        if (
            input == 0 || input > type(uint112).max || rIn == 0 || rOut == 0 || rIn > type(uint112).max
                || rOut > type(uint112).max
        ) revert InvalidAmount();
        uint256 withFee = input * 997;
        return Math.mulDiv(withFee, rOut, rIn * 1000 + withFee);
    }

    /// @notice Select proportional deposits; taxed liquidity deposits revert atomically.
    function addLiquidity(
        address a,
        address b,
        uint256 desiredA,
        uint256 desiredB,
        uint256 minA,
        uint256 minB,
        address to,
        uint256 deadline
    ) external nonReentrant timely(deadline) returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        _recipient(to);
        address pair = factory.getPair(a, b);
        if (pair == address(0)) pair = factory.createPair(a, b);
        (uint256 rA, uint256 rB) = _reserves(Pair(pair), a);
        (amountA, amountB) = (desiredA, desiredB);
        if (rA != 0 || rB != 0) {
            if (rA == 0 || rB == 0) revert InvalidAmount();
            uint256 optimalB = Math.mulDiv(desiredA, rB, rA);
            if (optimalB <= desiredB) amountB = optimalB;
            else amountA = Math.mulDiv(desiredB, rA, rB);
        }
        if (amountA == 0 || amountB == 0) revert InvalidAmount();
        if (amountA < minA || amountB < minB) revert Slippage();
        uint256 beforeA = IERC20(a).balanceOf(pair);
        uint256 beforeB = IERC20(b).balanceOf(pair);
        IERC20(a).safeTransferFrom(msg.sender, pair, amountA);
        IERC20(b).safeTransferFrom(msg.sender, pair, amountB);
        if (IERC20(a).balanceOf(pair) - beforeA != amountA || IERC20(b).balanceOf(pair) - beforeB != amountB) {
            revert UnsupportedTransfer();
        }
        liquidity = Pair(pair).mint(to);
    }

    /// @notice Redeem caller-authorized LP; minima apply to amounts actually received.
    function removeLiquidity(
        address a,
        address b,
        uint256 liquidity,
        uint256 minA,
        uint256 minB,
        address to,
        uint256 deadline
    ) external nonReentrant timely(deadline) returns (uint256 amountA, uint256 amountB) {
        _recipient(to);
        Pair pair = _pair(a, b);
        uint256 beforeA = IERC20(a).balanceOf(to);
        uint256 beforeB = IERC20(b).balanceOf(to);
        IERC20(address(pair)).safeTransferFrom(msg.sender, address(pair), liquidity);
        pair.burn(to);
        amountA = IERC20(a).balanceOf(to) - beforeA;
        amountB = IERC20(b).balanceOf(to) - beforeB;
        if (amountA < minA || amountB < minB) revert Slippage();
    }

    /// @notice Supports inclusive input/output transfer fees using measured balance deltas.
    /// @dev Rebasing, sender-extra-fee and arbitrary malicious tokens are outside the asset model.
    function swapExactTokensForTokens(
        address input,
        address output,
        uint256 amountIn,
        uint256 minOut,
        address to,
        uint256 deadline
    ) external nonReentrant timely(deadline) returns (uint256 received) {
        _recipient(to);
        Pair pair = _pair(input, output);
        if (to == address(pair)) revert InvalidRecipient();
        (uint256 rIn, uint256 rOut) = _reserves(pair, input);
        uint256 beforeIn = IERC20(input).balanceOf(address(pair));
        uint256 beforeOut = IERC20(output).balanceOf(to);
        IERC20(input).safeTransferFrom(msg.sender, address(pair), amountIn);
        uint256 actualIn = IERC20(input).balanceOf(address(pair)) - beforeIn;
        uint256 out = getAmountOut(actualIn, rIn, rOut);
        if (input == pair.token0()) pair.swap(0, out, to, "");
        else pair.swap(out, 0, to, "");
        received = IERC20(output).balanceOf(to) - beforeOut;
        if (received < minOut) revert Slippage();
    }

    function _pair(address a, address b) private view returns (Pair pair) {
        address addr = factory.getPair(a, b);
        if (addr == address(0)) revert MissingPair();
        return Pair(addr);
    }

    function _reserves(Pair pair, address a) private view returns (uint256 rA, uint256 rB) {
        (uint112 r0, uint112 r1,) = pair.getReserves();
        return a == pair.token0() ? (r0, r1) : (r1, r0);
    }

    function _recipient(address to) private view {
        if (to == address(0) || to == address(this) || to == address(1)) revert InvalidRecipient();
    }
}
