import type { Metadata } from "next";
import { Providers } from "./providers";
import "./globals.css";
export const metadata: Metadata = { title: "B2 AMM — Testnet Exchange", description: "Swap synthetic test tokens and provide liquidity on Base Sepolia. Non-custodial constant-product AMM." };
export default function RootLayout({ children }: { children: React.ReactNode }) {
  return <html lang="en"><body><Providers>{children}</Providers></body></html>;
}
