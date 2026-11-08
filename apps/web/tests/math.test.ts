import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { UNIT, MAX_RESERVE, parseAmount, formatAmount, amountOut, minimumAfterSlippage, optimalDeposit, withdrawal } from "../lib/math.ts";

test("strict decimal parsing preserves all raw units", () => {
  assert.equal(parseAmount("1.000000000000000001"), UNIT + 1n);
  assert.equal(parseAmount("0.000000000000000001"), 1n);
  for (const invalid of ["", "0", "-1", "1e18", "NaN", "01", ".5", "1.0000000000000000001"]) assert.throws(() => parseAmount(invalid));
  assert.throws(() => parseAmount((MAX_RESERVE + 1n).toString()));
});
test("display formatting truncates without modifying accounting", () => {
  assert.equal(formatAmount(UNIT + 999999999999n), "1");
  assert.equal(formatAmount(1234567890000000000n), "1.234567");
});
test("quote matches all Python rational vectors used by the contract suite", () => {
  const source = readFileSync("../../test/Differential.t.sol", "utf8");
  const hex = source.match(/hex"([0-9a-f]+)"/)![1];
  for (let offset=0;offset<hex.length;offset+=256) {
    const n=BigInt("0x"+hex.slice(offset,offset+64));
    const x=BigInt("0x"+hex.slice(offset+64,offset+128));
    const y=BigInt("0x"+hex.slice(offset+128,offset+192));
    const expected=BigInt("0x"+hex.slice(offset+192,offset+256));
    assert.equal(amountOut(n,x,y),expected);
  }
});
test("slippage never raises the permitted minimum", () => {
  assert.equal(minimumAfterSlippage(10001n,50n),9950n);
  assert.throws(()=>minimumAfterSlippage(100n,301n));
});
test("unbalanced deposit selects proportional amounts", () => {
  assert.deepEqual(optimalDeposit(20n,10n,100n,100n),{a:10n,b:10n});
  assert.deepEqual(optimalDeposit(10n,20n,100n,100n),{a:10n,b:10n});
  assert.throws(()=>optimalDeposit(1n,1n,0n,100n));
});
test("redemption respects share bounds and rejects sub-unit dust", () => {
  assert.deepEqual(withdrawal(50n,100n,200n,100n),{a:50n,b:100n});
  assert.throws(()=>withdrawal(1n,1n,200n,100n));
  assert.throws(()=>withdrawal(101n,100n,200n,100n));
});
