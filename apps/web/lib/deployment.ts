import { isAddress, type Address, type Hex } from "viem";
import record from "../deployment.json";
export type ContractName = "factory" | "router" | "pair" | "tokenA" | "tokenB";
export type Deployment = { status: "pending" | "verified"; chainId: 84532 | 31337; rpcUrl: string; explorerUrl: string; auditedCommit: string | null; contracts: Record<ContractName, Address> | null; runtimeHashes: Record<ContractName, Hex> | null };
export const deployment = record as Deployment;
if (![84532, 31337].includes(deployment.chainId)) throw new Error("Only approved test chains are supported.");
export function ready(): boolean {
  return deployment.status === "verified" && deployment.contracts !== null && deployment.runtimeHashes !== null &&
    Object.values(deployment.contracts).every(a => isAddress(a) && BigInt(a) !== 0n);
}
export function shorten(value: string) { return value.slice(0, 6) + "…" + value.slice(-4); }
export function explorer(kind: "address" | "tx", value: string) { return deployment.explorerUrl ? deployment.explorerUrl + "/" + kind + "/" + value : "#"; }
