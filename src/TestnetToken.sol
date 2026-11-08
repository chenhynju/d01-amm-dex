// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title Capped, permissionless faucet asset exclusively for test networks
/// @notice Synthetic test units have no monetary value or redemption promise.
contract TestnetToken is ERC20 {
    error UnsupportedChain(uint256 chainId);
    error ClaimNotReady(uint256 nextTimestamp);
    error FaucetExhausted();
    uint256 public constant CLAIM_AMOUNT = 1000 ether;
    uint256 public constant CLAIM_INTERVAL = 1 hours;
    uint256 public constant MAX_SUPPLY = 1_000_000_000 ether;
    mapping(address => uint256) public nextClaimAt;
    event Claimed(address indexed account, uint256 amount, uint256 nextTimestamp);

    /// @param symbol_ Public demo symbol; the deployed contract has no mint administrator.
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {
        if (block.chainid != 31337 && block.chainid != 84532) revert UnsupportedChain(block.chainid);
    }

    /// @notice Claim fixed test units once per address per hour, subject to the global cap.
    /// @dev Sybil resistance is not claimed; the faucet is not an economic security primitive.
    function claim() external {
        uint256 next = nextClaimAt[msg.sender];
        if (block.timestamp < next) revert ClaimNotReady(next);
        if (totalSupply() > MAX_SUPPLY - CLAIM_AMOUNT) revert FaucetExhausted();
        next = block.timestamp + CLAIM_INTERVAL;
        nextClaimAt[msg.sender] = next;
        _mint(msg.sender, CLAIM_AMOUNT);
        emit Claimed(msg.sender, CLAIM_AMOUNT, next);
    }
}
