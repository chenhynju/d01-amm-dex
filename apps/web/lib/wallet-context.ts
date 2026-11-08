/** Revalidate the live wallet after asynchronous simulation and before signing. */
type ContextWallet = { getChainId(): Promise<number>; getAddresses(): Promise<readonly string[]> };
export async function assertWalletContext(wallet: ContextWallet, account: string, chainId: number) {
  const [actualChain, accounts] = await Promise.all([wallet.getChainId(), wallet.getAddresses()]);
  if (actualChain !== chainId || accounts[0]?.toLowerCase() !== account.toLowerCase())
    throw new Error("Wallet account or network changed. Restart this operation.");
}
export async function prepareWalletRequest<T>(wallet: ContextWallet, account: string, chainId: number, simulate: () => Promise<T>): Promise<T> {
  await assertWalletContext(wallet, account, chainId);
  const request = await simulate();
  await assertWalletContext(wallet, account, chainId);
  return request;
}
