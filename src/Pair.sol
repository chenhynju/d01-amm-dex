// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IFlashCallee {
    function ammCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external;
}

/// @title Constant product pool and transferable LP receipt
/// @notice V2-style mechanics, fixed 30 bps LP fee; no protocol fee or privileged withdrawals.
/// @dev Donations are public surplus until mint/sync; direct transfers must be atomic with use.
contract Pair is ERC20, ERC20Permit, ReentrancyGuard {
    using SafeERC20 for IERC20;

    error InvalidTokens();
    error InvalidRecipient();
    error InsufficientLiquidity();
    error InsufficientInput();
    error InvariantViolation();
    error Overflow();

    uint256 public constant MINIMUM_LIQUIDITY = 1000;
    address public constant LOCKED_LP = address(1);
    address public immutable token0;
    address public immutable token1;
    uint112 private reserve0;
    uint112 private reserve1;
    uint32 private timestampLast;
    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;

    event Mint(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);
    event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    constructor(address a, address b) ERC20("B2 Liquidity", "B2-LP") ERC20Permit("B2 Liquidity") {
        if (a == address(0) || a >= b || a.code.length == 0 || b.code.length == 0) revert InvalidTokens();
        token0 = a;
        token1 = b;
    }

    /// @notice Reverts during asset-moving callbacks to prevent consumers reading transient reserves.
    function getReserves() external view returns (uint112, uint112, uint32) {
        _assertUnlocked();
        return (reserve0, reserve1, timestampLast);
    }

    /// @notice Counterfactual Q112 cumulative prices, modulo 2^256; not a ready-to-use oracle.
    function currentCumulativePrices() external view returns (uint256 p0, uint256 p1, uint32 now32) {
        _assertUnlocked();
        p0 = price0CumulativeLast;
        p1 = price1CumulativeLast;
        now32 = uint32(block.timestamp);
        unchecked {
            uint32 elapsed = now32 - timestampLast;
            if (reserve0 != 0 && reserve1 != 0) {
                p0 += ((uint256(reserve1) << 112) / reserve0) * elapsed;
                p1 += ((uint256(reserve0) << 112) / reserve1) * elapsed;
            }
        }
    }

    /// @notice Mint against balance increases. Minimum liquidity is permanently inaccessible.
    function mint(address to) external nonReentrant returns (uint256 liquidity) {
        _recipient(to);
        (uint256 b0, uint256 b1) = _balances();
        uint256 a0 = b0 - reserve0;
        uint256 a1 = b1 - reserve1;
        uint256 supply = totalSupply();
        if (supply == 0) {
            uint256 root = Math.sqrt(a0 * a1);
            if (root <= MINIMUM_LIQUIDITY) revert InsufficientLiquidity();
            liquidity = root - MINIMUM_LIQUIDITY;
            _mint(LOCKED_LP, MINIMUM_LIQUIDITY);
        } else {
            liquidity = Math.min(Math.mulDiv(a0, supply, reserve0), Math.mulDiv(a1, supply, reserve1));
        }
        if (liquidity == 0) revert InsufficientLiquidity();
        _mint(to, liquidity);
        _updateReserves(b0, b1);
        emit Mint(msg.sender, a0, a1, to);
    }

    /// @notice Burn LP already transferred to this pair, redeeming pro-rata current balances.
    function burn(address to) external nonReentrant returns (uint256 a0, uint256 a1) {
        _recipient(to);
        (uint256 b0, uint256 b1) = _balances();
        uint256 liquidity = balanceOf(address(this));
        uint256 supply = totalSupply();
        a0 = Math.mulDiv(liquidity, b0, supply);
        a1 = Math.mulDiv(liquidity, b1, supply);
        if (a0 == 0 || a1 == 0) revert InsufficientLiquidity();
        _burn(address(this), liquidity);
        IERC20(token0).safeTransfer(to, a0);
        IERC20(token1).safeTransfer(to, a1);
        (b0, b1) = _balances();
        _updateReserves(b0, b1);
        emit Burn(msg.sender, a0, a1, to);
    }

    /// @notice Optimistic output and optional callback; repayment must satisfy the fee-adjusted product.
    function swap(uint256 a0Out, uint256 a1Out, address to, bytes calldata data) external nonReentrant {
        _recipient(to);
        if (a0Out == 0 && a1Out == 0) revert InsufficientLiquidity();
        if (a0Out >= reserve0 || a1Out >= reserve1) revert InsufficientLiquidity();
        if (a0Out != 0) IERC20(token0).safeTransfer(to, a0Out);
        if (a1Out != 0) IERC20(token1).safeTransfer(to, a1Out);
        if (data.length != 0) IFlashCallee(to).ammCall(msg.sender, a0Out, a1Out, data);
        (uint256 b0, uint256 b1) = _balances();
        uint256 a0In = b0 > reserve0 - a0Out ? b0 - (reserve0 - a0Out) : 0;
        uint256 a1In = b1 > reserve1 - a1Out ? b1 - (reserve1 - a1Out) : 0;
        if (a0In == 0 && a1In == 0) revert InsufficientInput();
        uint256 adjusted0 = b0 * 1000 - a0In * 3;
        uint256 adjusted1 = b1 * 1000 - a1In * 3;
        if (adjusted0 * adjusted1 < uint256(reserve0) * reserve1 * 1_000_000) revert InvariantViolation();
        _updateReserves(b0, b1);
        emit Swap(msg.sender, a0In, a1In, a0Out, a1Out, to);
    }

    /// @notice Publicly recover surplus; this is intentionally not donation ownership tracking.
    function skim(address to) external nonReentrant {
        _recipient(to);
        IERC20(token0).safeTransfer(to, IERC20(token0).balanceOf(address(this)) - reserve0);
        IERC20(token1).safeTransfer(to, IERC20(token1).balanceOf(address(this)) - reserve1);
    }

    /// @notice Reconcile reserves to balances, including losses from unsupported rebases.
    function sync() external nonReentrant {
        (uint256 b0, uint256 b1) = _balances();
        _updateReserves(b0, b1);
    }

    function _assertUnlocked() private view {
        if (_reentrancyGuardEntered()) revert ReentrancyGuardReentrantCall();
    }

    function _recipient(address to) private view {
        if (to == address(0) || to == address(this) || to == token0 || to == token1 || to == LOCKED_LP) {
            revert InvalidRecipient();
        }
    }

    function _balances() private view returns (uint256 b0, uint256 b1) {
        b0 = IERC20(token0).balanceOf(address(this));
        b1 = IERC20(token1).balanceOf(address(this));
        if (b0 > type(uint112).max || b1 > type(uint112).max) revert Overflow();
    }

    function _updateReserves(uint256 b0, uint256 b1) private {
        uint32 now32 = uint32(block.timestamp);
        unchecked {
            uint32 elapsed = now32 - timestampLast;
            if (elapsed != 0 && reserve0 != 0 && reserve1 != 0) {
                price0CumulativeLast += ((uint256(reserve1) << 112) / reserve0) * elapsed;
                price1CumulativeLast += ((uint256(reserve0) << 112) / reserve1) * elapsed;
            }
        }
        reserve0 = SafeCast.toUint112(b0);
        reserve1 = SafeCast.toUint112(b1);
        timestampLast = now32;
        emit Sync(reserve0, reserve1);
    }
}
