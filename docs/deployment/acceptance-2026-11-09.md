# D01 AMM acceptance evidence

Evidence index prepared 2026-11-09. Repository inspected at `0670428a32a3a9b3125365d2a65a49513711ef50`. Individual reports and deployment manifests identify the source that was tested or deployed.

| Gate | Result |
| --- | --- |
| Local engineering | PASS within the tested scope |
| Security self-review | Recorded in [AI-Assisted Self-Assessment](../audit/review-2026-11-08.md) |
| Independent third-party audit | NOT RUN |
| Owner learning mastery | NOT RUN |

## Local verification

43 Solidity checks passed with one optional fork check skipped. Ten frontend tests and the local browser swap and LP roundtrip passed. [Browser log](../../evidence/review-2026-11-08/d01-browser-final.log).

## Public testnet

Base Sepolia deployment PASS. The journal contains nine successful receipts for deployment and setup, including liquidity initialization. Five contracts have Sourcify exact-match results. [Deployment](../../deployments/base-sepolia-20261108.json) and [source verification](../../evidence/review-2026-11-08/source-verification.json).

## Remaining scope

Fresh public-wallet swap and LP exit after deployment are NOT RUN. [Hosted UI rendering](../../evidence/hosted-ui-20261109/acceptance.json) passed separately. Six moderate development lint advisories remain recorded.
