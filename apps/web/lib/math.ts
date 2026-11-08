/** Raw integer accounting. Never use JS floating point for asset amounts. */
export const UNIT = 10n ** 18n;
export const MAX_RESERVE = (1n << 112n) - 1n;

export function parseAmount(text: string): bigint {
  if (!/^(0|[1-9][0-9]*)(\.[0-9]{0,18})?$/.test(text)) throw new Error("Enter a decimal amount with up to 18 digits.");
  const [whole, fraction = ""] = text.split(".");
  const result = BigInt(whole) * UNIT + BigInt(fraction.padEnd(18, "0"));
  if (result <= 0n || result > MAX_RESERVE) throw new Error("Amount is outside the supported range.");
  return result;
}

export function formatAmount(value: bigint, digits = 6): string {
  if (value < 0n) return "−" + formatAmount(-value, digits);
  const whole = value / UNIT;
  const fraction = (value % UNIT).toString().padStart(18, "0").slice(0, digits).replace(/0+$/, "");
  return whole.toString() + (fraction ? "." + fraction : "");
}

export function amountOut(input: bigint, rIn: bigint, rOut: bigint): bigint {
  if (input <= 0n || rIn <= 0n || rOut <= 0n || input > MAX_RESERVE || rIn > MAX_RESERVE || rOut > MAX_RESERVE) throw new Error("Pool or amount is invalid.");
  return input * 997n * rOut / (rIn * 1000n + input * 997n);
}

export function minimumAfterSlippage(amount: bigint, bps: bigint): bigint {
  if (amount < 0n || bps < 0n || bps > 300n) throw new Error("Slippage must be between 0% and 3%.");
  return amount * (10000n - bps) / 10000n;
}

export function optimalDeposit(a: bigint, b: bigint, rA: bigint, rB: bigint) {
  if (a <= 0n || b <= 0n || rA <= 0n || rB <= 0n) throw new Error("Enter both amounts for an active pool.");
  const optimalB = a * rB / rA;
  const usedA = optimalB <= b ? a : b * rA / rB;
  const usedB = optimalB <= b ? optimalB : b;
  if (usedA <= 0n || usedB <= 0n || rA + usedA > MAX_RESERVE || rB + usedB > MAX_RESERVE) throw new Error("Deposit cannot be represented safely.");
  return { a: usedA, b: usedB };
}

export function withdrawal(lp: bigint, rA: bigint, rB: bigint, supply: bigint) {
  if (lp <= 0n || supply <= 0n || lp > supply) throw new Error("Select a valid LP amount.");
  const a = lp * rA / supply, b = lp * rB / supply;
  if (a === 0n || b === 0n) throw new Error("This LP amount is too small to redeem in both tokens.");
  return { a, b };
}

export function percentage(value: bigint, total: bigint): string {
  if (total === 0n) return "0.00";
  const bps = value * 10000n / total;
  return (bps / 100n).toString() + "." + (bps % 100n).toString().padStart(2, "0");
}
