import test from "node:test";
import assert from "node:assert/strict";
import { prepareWalletRequest } from "../lib/wallet-context.ts";
const account = "0x1111111111111111111111111111111111111111";
test("wallet context is checked before and after simulation", async () => {
  const wallet = { getChainId: async () => 84532, getAddresses: async () => [account] };
  assert.deepEqual(await prepareWalletRequest(wallet, account, 84532, async () => ({ gas: 1n })), { gas: 1n });
});
for (const kind of ["chain", "account"] as const) test(`${kind} switch during simulation rejects the stale request`, async () => {
  let chain = 84532, actor = account;
  const wallet = { getChainId: async () => chain, getAddresses: async () => [actor] };
  await assert.rejects(prepareWalletRequest(wallet, account, 84532, async () => {
    if (kind === "chain") chain = 1;
    else actor = "0x2222222222222222222222222222222222222222";
    return { gas: 1n };
  }), /changed/);
});
test("wrong initial chain never starts simulation", async () => {
  let called = false;
  const wallet = { getChainId: async () => 1, getAddresses: async () => [account] };
  await assert.rejects(prepareWalletRequest(wallet, account, 84532, async () => { called = true; }), /changed/);
  assert.equal(called, false);
});
