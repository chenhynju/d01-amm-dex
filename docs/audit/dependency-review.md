# Dependency review and provenance
Local measured dependencies: vendored OpenZeppelin Contracts 5.4.0, forge-std 1.14.0; all file hashes locked. Requested 5.0.2 Git install and HTTPS archive fetches failed with connection resets. The cached trees have no usable upstream Git metadata. Their package version and hashes identify what was tested, but do not independently authenticate upstream source.

A limited current primary-source advisory review was performed via the web tool on 2026-11-05:
- [OZ published advisories](https://github.com/OpenZeppelin/openzeppelin-contracts/security/advisories) were inspected; this is not an exhaustive vulnerability-database attestation.
- [GHSA-9rcw-c2f9-2j55](https://github.com/OpenZeppelin/openzeppelin-contracts/security/advisories/GHSA-9rcw-c2f9-2j55) lists 5.4.0 as patched. Bytes.lastIndexOf is not used by our source.
- [GHSA-4h98-2769-gh6h](https://github.com/OpenZeppelin/openzeppelin-contracts/security/advisories/GHSA-4h98-2769-gh6h) affects a v4 ECDSA range, not nominal v5.4.0. Our permit uses inherited nonce replay protection and r/v/s recovery.
No broad claim of zero dependency CVEs is made. Online machine package audit, cache authenticity and complete toolchain dependency audit are BLOCKED / NOT RUN.

Foundry 1.8.1 was preserved for measured reproducibility; it is not current. [Official 1.8.7 release](https://github.com/foundry-rs/foundry/releases/tag/v1.8.7) includes security dependency fixes. Upgrade and rerun before public release. Do not silently mix 1.8.7 gas/coverage with the 1.8.1 evidence.

OZ v5 checks: no Ownable, Ownable2Step, AccessControl or upgradeable storage is used (N/A). ERC20/permit constructor initialization follows v5; zero-address mint is disallowed, so locked LP uses address(1). Storage ReentrancyGuard is tested for nested/cross-function and read-only callbacks. Transient alternative is not selected, not gas-benchmarked and not fork-validated.

Compiler known-bug comparison was subsequently performed; see compiler-review.md. Public release remains blocked pending a patched compiler and new evidence.
