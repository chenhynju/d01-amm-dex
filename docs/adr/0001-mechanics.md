# ADR 1 — Fixed product, bounded integers, storage guard
Context: demonstrate independently implemented protocol accounting in Solidity 0.8.28, with mature ERC20/signature primitives.
Decision: V2-inspired 997/1000 input fee, uint112 reserves, floor outputs/LP claims, sqrt initial supply, permanently lock 1000 LP units. No admin, upgrade or protocol-fee switch. Require current balance <= uint112 max before product arithmetic.
Alternatives: concentrated liquidity (different project scope), exact-output/multihop routers (larger review surface), custom ERC20/permit (unnecessary signature risk), ERC4626 (single-asset vault semantics do not model AMM LP).
Trade-offs: permanent dust, arbitrary token listing, public donations and MEV exposure. Floor rounding protects the pool, but deposits may donate dust and swaps may return zero and revert.
Security: storage-based OZ guard avoids EIP-1153 dependence. Cached OZ 5.4 includes transient guard, but it is not imported. No transient-vs-storage gas claim is made; transient variant and fork parity are NOT RUN.
Performance: optimizer and via-IR comparisons are measured separately; bytecode bounds checked against EIP-170/EIP-3860. Factory embeds pair initcode so both contracts must be measured.
Rejected: admin rescue (custody risk), spot-price oracle (manipulation), silent fallback oracle (no independent source).
