# ADR 0002 — Upgrade the wallet connector dependency tree

Date: 2026-11-08. Status: implemented, validation recorded separately.

## Context
The original default was wagmi v2. The current production dependency audit found 27 affected packages (16 High, 11 Moderate), largely in its fixed connector/SDK dependency tree. A static injected-wallet UI still needs an explicit disposition of those installed dependencies; hiding audit warnings does not fix them.

## Decision
Pin wagmi 3.7.11 and retain the existing injected-wallet UX, viem v2 and TanStack Query v5. Pin patched PostCSS 8.5.32 and sharp 0.35.5. Validate TypeScript, wallet-context regressions, production build, dependency audit and browser transactions before release. Keep the previous audit as before-fix evidence.

## Alternatives and trade-offs
Remaining on v2 with many independent transitive overrides risks incompatible SDK combinations. Replacing wagmi with custom wallet state would add maintenance and security burden. The major upgrade requires explicit API/build/browser verification; a lockfile change alone is not acceptance. This intentionally updates the default v2 baseline for a concrete security reason.

## Security and performance
No signing key enters the frontend. Network/account revalidation and bounded approvals remain. Dependency closure and actual shipped behavior must both be reviewed; bundle size is measured after the final build rather than assumed to improve.
