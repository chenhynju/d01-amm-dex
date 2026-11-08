"use client";
import { useState } from "react";
import { WagmiProvider, createConfig, http, injected } from "wagmi";
import { baseSepolia, foundry } from "wagmi/chains";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { deployment } from "../lib/deployment";
const config = createConfig({ chains: [baseSepolia, foundry], connectors: [injected()],
  transports: { [baseSepolia.id]: http(deployment.chainId === 84532 ? deployment.rpcUrl : "https://sepolia.base.org", { timeout: 15000, retryCount: 1 }),
    [foundry.id]: http(deployment.chainId === 31337 ? deployment.rpcUrl : "http://127.0.0.1:18545") }, ssr: true });
export function Providers({ children }: { children: React.ReactNode }) {
  const [queryClient] = useState(() => new QueryClient());
  return <WagmiProvider config={config}><QueryClientProvider client={queryClient}>{children}</QueryClientProvider></WagmiProvider>;
}
