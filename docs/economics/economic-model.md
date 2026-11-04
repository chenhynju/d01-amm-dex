# Economic model
Assets: two raw ERC20 balances b0,b1. LP supply S represents proportional claims, not an asset-denominated equality S=b0+b1. No debt, rewards, subsidies, reserve treasury or protocol fees.
All parameters are immutable: fee 3/1000 input, minimum liquidity 1000 raw 18-decimal LP units, maximum reserve 2^112-1 raw units. Token decimals are independent; formulas operate in raw units.

Initial S=floor(sqrt(a0*a1)); issuer gets S-1000. Subsequent mint=min(floor(a0*S/r0),floor(a1*S/r1)). Burn returns floor(l*b0/S), floor(l*b1/S). Swap out=floor(997*in*rOut/(1000*rIn+997*in)). Enforce (1000*b0-3*in0)*(1000*b1-3*in1)>=10^6*r0*r1.
Fee stays in reserves; sqrt(k)/S grows across trades with fixed supply, but liquidity changes, donations and rebases invalidate naive global k monotonicity.
Spot raw price=r1/r0. Human price adjusts by 10^(decimals0-decimals1). Accumulate Q112 ratios times uint32 elapsed seconds; wrap arithmetic is intentional. A consumer needs two observations, a bounded nonzero interval, liquidity checks and independent freshness/sequencer policy; no production price feed is delivered.

Risks: impermanent loss, toxic order flow, sandwiches, front-running initial liquidity, donation capture, frozen assets and token issuers. LP can lose nearly all external market value. No guaranteed principal or return. Minimum liquidity raises donation-inflation cost but does not eliminate all griefing or dust rounding.
