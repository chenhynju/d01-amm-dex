"use client";
import { useCallback, useEffect, useMemo, useState } from "react";
import { useAccount, useConnect, useDisconnect, usePublicClient, useSwitchChain, useWalletClient } from "wagmi";
import { erc20Abi, keccak256, type Abi, type Address, type Hash } from "viem";
import { factoryAbi, pairAbi, routerAbi, faucetAbi } from "../lib/contracts";
import { prepareWalletRequest } from "../lib/wallet-context";
import { deployment, ready, shorten, explorer } from "../lib/deployment";
import { MAX_RESERVE, parseAmount, formatAmount, amountOut, minimumAfterSlippage, optimalDeposit, withdrawal, percentage } from "../lib/math";

type Snapshot = { rA: bigint; rB: bigint; supply: bigint; a: bigint; b: bigint; lp: bigint; nextA: bigint; nextB: bigint; block: bigint };
type Transaction = { phase: "idle" | "signing" | "pending" | "confirmed" | "failed"; message: string; hash?: Hash };
type Receipt = { label: string; hash: Hash };
type Mode = "swap" | "add" | "remove";
const chainName = deployment.chainId === 84532 ? "Base Sepolia" : "Local Anvil";
const initialTx: Transaction = { phase: "idle", message: "" };

function TokenBadge({ name }: { name: "B2A" | "B2B" }) {
  return <span className={"token-badge " + (name === "B2B" ? "secondary" : "")}>{name === "B2A" ? "A" : "B"}</span>;
}

export default function Exchange() {
  const { address, isConnected, chainId } = useAccount();
  const { connectors, connectAsync, isPending: connecting } = useConnect();
  const { disconnect } = useDisconnect();
  const { switchChainAsync } = useSwitchChain();
  const publicClient = usePublicClient({ chainId: deployment.chainId });
  const { data: walletClient } = useWalletClient();
  const [mode, setMode] = useState<Mode>("swap");
  const [reverse, setReverse] = useState(false);
  const [input, setInput] = useState("");
  const [depositA, setDepositA] = useState("");
  const [depositB, setDepositB] = useState("");
  const [exitBps, setExitBps] = useState("10000");
  const [slippage, setSlippage] = useState("50");
  const [snapshot, setSnapshot] = useState<Snapshot | null>(null);
  const [issue, setIssue] = useState("");
  const [loading, setLoading] = useState(false);
  const [verified, setVerified] = useState(false);
  const [tx, setTx] = useState<Transaction>(initialTx);
  const [receipts, setReceipts] = useState<Receipt[]>([]);
  const [now, setNow] = useState(0);
  const busy = tx.phase === "signing" || tx.phase === "pending";
  const wrongChain = isConnected && chainId !== deployment.chainId;
  const configured = ready();
  const c = deployment.contracts;

  const refresh = useCallback(async () => {
    if (!publicClient || !ready() || !deployment.contracts || !deployment.runtimeHashes) return;
    const contracts = deployment.contracts;
    setLoading(true);
    try {
      if (await publicClient.getChainId() !== deployment.chainId) throw new Error("RPC network does not match this deployment.");
      for (const key of Object.keys(contracts) as Array<keyof typeof contracts>) {
        const code = await publicClient.getBytecode({ address: contracts[key] });
        if (!code || keccak256(code).toLowerCase() !== deployment.runtimeHashes[key].toLowerCase()) throw new Error("Contract code does not match the verified deployment.");
      }
      const [registered, routerFactory, token0, token1] = await Promise.all([
        publicClient.readContract({ address: contracts.factory, abi: factoryAbi, functionName: "getPair", args: [contracts.tokenA, contracts.tokenB] }),
        publicClient.readContract({ address: contracts.router, abi: routerAbi, functionName: "factory" }),
        publicClient.readContract({ address: contracts.pair, abi: pairAbi, functionName: "token0" }),
        publicClient.readContract({ address: contracts.pair, abi: pairAbi, functionName: "token1" }),
      ]);
      if (registered.toLowerCase() !== contracts.pair.toLowerCase() || routerFactory.toLowerCase() !== contracts.factory.toLowerCase() ||
        ![token0.toLowerCase(), token1.toLowerCase()].includes(contracts.tokenA.toLowerCase()) ||
        ![token0.toLowerCase(), token1.toLowerCase()].includes(contracts.tokenB.toLowerCase())) throw new Error("Pool registry does not match the published configuration.");
      const [reserves, supply, block] = await Promise.all([
        publicClient.readContract({ address: contracts.pair, abi: pairAbi, functionName: "getReserves" }),
        publicClient.readContract({ address: contracts.pair, abi: erc20Abi, functionName: "totalSupply" }),
        publicClient.getBlockNumber(),
      ]);
      let a=0n,b=0n,lp=0n,nextA=0n,nextB=0n;
      if (address) [a,b,lp,nextA,nextB] = await Promise.all([
        publicClient.readContract({ address: contracts.tokenA, abi: erc20Abi, functionName: "balanceOf", args: [address] }),
        publicClient.readContract({ address: contracts.tokenB, abi: erc20Abi, functionName: "balanceOf", args: [address] }),
        publicClient.readContract({ address: contracts.pair, abi: erc20Abi, functionName: "balanceOf", args: [address] }),
        publicClient.readContract({ address: contracts.tokenA, abi: faucetAbi, functionName: "nextClaimAt", args: [address] }),
        publicClient.readContract({ address: contracts.tokenB, abi: faucetAbi, functionName: "nextClaimAt", args: [address] }),
      ]);
      const aIs0 = token0.toLowerCase() === contracts.tokenA.toLowerCase();
      setSnapshot({ rA: aIs0 ? BigInt(reserves[0]) : BigInt(reserves[1]), rB: aIs0 ? BigInt(reserves[1]) : BigInt(reserves[0]), supply, a,b,lp,nextA,nextB,block });
      setVerified(true); setIssue("");
    } catch (error) {
      setVerified(false); setIssue(error instanceof Error ? error.message.split("\n")[0] : "Unable to refresh this pool.");
    } finally { setLoading(false); }
  }, [publicClient, address]);

  useEffect(() => { void refresh(); const timer=setInterval(()=>void refresh(),30000); return ()=>clearInterval(timer); }, [refresh]);
  useEffect(() => { setNow(Math.floor(Date.now()/1000)); const timer=setInterval(()=>setNow(Math.floor(Date.now()/1000)),1000); return ()=>clearInterval(timer); }, []);

  const quote = useMemo(() => {
    if (!snapshot) return null;
    try {
      const bps=BigInt(slippage);
      if (mode === "swap") {
        const amount=parseAmount(input);
        const rIn=reverse?snapshot.rB:snapshot.rA, rOut=reverse?snapshot.rA:snapshot.rB;
        if (rIn+amount>MAX_RESERVE) throw new Error("Input exceeds the pool reserve limit.");
        const out=amountOut(amount,rIn,rOut);
        if (out===0n) throw new Error("Amount is too small for an output unit.");
        return { amount, out, minOut: minimumAfterSlippage(out,bps), a:0n,b:0n,lp:0n };
      }
      if (mode === "add") {
        const a=parseAmount(depositA), b=parseAmount(depositB);
        const used=optimalDeposit(a,b,snapshot.rA,snapshot.rB);
        const lpA=used.a*snapshot.supply/snapshot.rA,lpB=used.b*snapshot.supply/snapshot.rB;
        const lp=lpA<lpB?lpA:lpB;
        if (lp===0n) throw new Error("Deposit is too small to mint LP.");
        return { amount:0n,out:0n,minOut:0n,a:used.a,b:used.b,lp };
      }
      const lp=snapshot.lp*BigInt(exitBps)/10000n;
      const amounts=withdrawal(lp,snapshot.rA,snapshot.rB,snapshot.supply);
      return { amount:0n,out:0n,minOut:0n,a:amounts.a,b:amounts.b,lp };
    } catch { return null; }
  }, [snapshot, mode, input, reverse, slippage, depositA, depositB, exitBps]);

  function explain(error: unknown) {
    const message=error instanceof Error ? error.message : String(error);
    if (/reject|denied|4001/i.test(message)) return "Request rejected in your wallet. Any earlier confirmed approval remains recorded below.";
    if (/insufficient funds/i.test(message)) return "Your wallet needs test ETH on " + chainName + " for gas.";
    return message.split("\n")[0].slice(0,240);
  }

  async function connectWallet() {
    try {
      setIssue("");
      const connector=connectors[0];
      if (!connector || !await connector.getProvider()) throw new Error("No browser wallet detected. Open this page in a browser with MetaMask or another injected wallet.");
      await connectAsync({ connector });
    } catch (error) { setIssue(explain(error)); }
  }

  async function send(request: { address: Address; abi: Abi; functionName: string; args?: readonly unknown[] }, label: string) {
    if (!publicClient || !walletClient || !address) throw new Error("Connect a wallet first.");
    if (await walletClient.getChainId() !== deployment.chainId || await publicClient.getChainId() !== deployment.chainId) throw new Error("Network changed. Switch back to " + chainName + ".");
    const accounts=await walletClient.getAddresses();
    if (accounts[0]?.toLowerCase()!==address.toLowerCase()) throw new Error("Wallet account changed. Restart this operation.");
    setTx({ phase:"signing",message:label + " — review in your wallet" });
    const simulation=await prepareWalletRequest(walletClient,address,deployment.chainId,
      ()=>publicClient.simulateContract({ ...request, account: address }));
    const hash=await walletClient.writeContract({ ...simulation.request, account: address, chain: publicClient.chain });
    setTx({ phase:"pending",message:label + " — waiting for confirmation",hash });
    const receipt=await publicClient.waitForTransactionReceipt({ hash, confirmations:1, timeout:120000 });
    if (receipt.status!=="success") throw new Error(label + " reverted on-chain.");
    setReceipts(old=>[{label,hash},...old].slice(0,8));
    return hash;
  }

  async function approve(token: Address, amount: bigint, symbol: string) {
    if (!publicClient || !address || !c) throw new Error("Connect a wallet first.");
    const allowance=await publicClient.readContract({ address: token, abi: erc20Abi, functionName:"allowance",args:[address,c.router] });
    if (allowance>=amount) return;
    if (allowance>0n) await send({address:token,abi:erc20Abi,functionName:"approve",args:[c.router,0n]},"Reset " + symbol + " approval");
    await send({address:token,abi:erc20Abi,functionName:"approve",args:[c.router,amount]},"Approve " + symbol);
  }

  async function perform(action: Mode | "claimA" | "claimB") {
    if (!configured || !c || !publicClient || !address || !verified) return;
    if (wrongChain) { try { await switchChainAsync({ chainId:deployment.chainId }); } catch(error){setIssue(explain(error));} return; }
    try {
      setIssue("");setTx({phase:"signing",message:"Preparing transaction"});
      const block=await publicClient.getBlock();
      const deadline=block.timestamp+1200n;
      let hash: Hash;
      if (action==="claimA" || action==="claimB") {
        const token=action==="claimA"?c.tokenA:c.tokenB;
        hash=await send({address:token,abi:faucetAbi,functionName:"claim"},"Claim " + (action==="claimA"?"B2A":"B2B"));
      } else {
        if (!quote || !snapshot) throw new Error("Enter a valid amount and refresh the pool.");
        const bps=BigInt(slippage);
        if (action==="swap") {
          const tokenIn=reverse?c.tokenB:c.tokenA,tokenOut=reverse?c.tokenA:c.tokenB;
          if (quote.amount>(reverse?snapshot.b:snapshot.a)) throw new Error("Insufficient test token balance.");
          await approve(tokenIn,quote.amount,reverse?"B2B":"B2A");
          hash=await send({address:c.router,abi:routerAbi,functionName:"swapExactTokensForTokens",args:[tokenIn,tokenOut,quote.amount,quote.minOut,address,deadline]},"Swap tokens");
        } else if (action==="add") {
          const a=parseAmount(depositA),b=parseAmount(depositB);
          if (a>snapshot.a || b>snapshot.b) throw new Error("Insufficient test token balance.");
          await approve(c.tokenA,a,"B2A");await approve(c.tokenB,b,"B2B");
          hash=await send({address:c.router,abi:routerAbi,functionName:"addLiquidity",args:[c.tokenA,c.tokenB,a,b,minimumAfterSlippage(quote.a,bps),minimumAfterSlippage(quote.b,bps),address,deadline]},"Add liquidity");
        } else {
          await approve(c.pair,quote.lp,"LP");
          hash=await send({address:c.router,abi:routerAbi,functionName:"removeLiquidity",args:[c.tokenA,c.tokenB,quote.lp,minimumAfterSlippage(quote.a,bps),minimumAfterSlippage(quote.b,bps),address,deadline]},"Remove liquidity");
        }
      }
      setTx({phase:"confirmed",message:action==="swap"?"Swap confirmed":action==="add"?"Liquidity added":action==="remove"?"Liquidity removed":"Test tokens claimed",hash});
      await refresh();
    } catch(error) { setTx({phase:"failed",message:explain(error)}); await refresh(); }
  }

  async function mainAction() {
    if (!isConnected) return connectWallet();
    if (wrongChain) {try{await switchChainAsync({chainId:deployment.chainId});}catch(error){setIssue(explain(error));}return;}
    await perform(mode);
  }
  const balanceIn=snapshot?(reverse?snapshot.b:snapshot.a):0n;
  const label=!configured?"Deployment pending":!isConnected?"Connect wallet":wrongChain?"Switch to "+chainName:busy?"Check transaction status":mode==="swap"?"Swap tokens":mode==="add"?"Add liquidity":"Remove liquidity";
  const canAct=configured&&!busy&&(!isConnected||wrongChain||(verified&&quote!==null));
  const claimLabel=(next:bigint|undefined)=>next&&next>BigInt(now)?"Available in "+Math.ceil(Number(next-BigInt(now))/60)+"m":"Claim 1,000";
  const fee=mode==="swap"&&quote?quote.amount*3n/1000n:0n;

  return <div className="app-shell">
    <header className="site-header">
      <a className="brand" href="#" aria-label="B2 AMM home"><span className="brand-mark"><i/><i/><i/></span><span>B2<span className="brand-suffix"> / AMM</span></span></a>
      <nav aria-label="Main navigation"><button className="nav-active" onClick={()=>setMode("swap")}>Exchange</button><a href="#protocol">Protocol</a></nav>
      <div className="header-actions"><span className="network-pill"><span/>{chainName}</span>{isConnected?<button className="wallet-button" onClick={()=>disconnect()} title="Disconnect wallet">{shorten(address!)} <span>↗</span></button>:<button className="wallet-button" onClick={()=>void connectWallet()} disabled={connecting}>{connecting?"Connecting…":"Connect wallet"} <span>↗</span></button>}</div>
    </header>
    <main>
      <div className="testnet-notice"><span className="notice-dot"/> A testnet exchange. Real transactions, synthetic assets.<span className="notice-tag">NO REAL FUNDS</span></div>
      <section className="exchange-grid" aria-label="Exchange workspace">
        <aside className="intro-column">
          <div className="eyebrow"><span className="tiny-line"/> CONSTANT PRODUCT / 01</div>
          <h1>A pool.<br/>A formula.<br/><span>Your move.</span></h1>
          <p>Swap test tokens or provide liquidity. Every trade settles on-chain, with rules you can inspect.</p>
          <div className="principles"><span>Non-custodial</span><span>Permissionless</span><span>Fixed 0.3% fee</span></div>
          <div className="curve-art" aria-hidden="true"><svg viewBox="0 0 250 140"><path className="axis" d="M15 10V125H245"/><path className="curve-shadow" d="M30 15C40 75 80 105 235 113"/><path className="curve-line" d="M30 15C40 75 80 105 235 113"/><circle cx="91" cy="95" r="5"/></svg><span>x · y = k</span></div>
        </aside>
        <section className="trade-panel">
          <div className="panel-heading"><div><span className="eyebrow">THE EXCHANGE</span><h2>{mode==="swap"?"Swap tokens":mode==="add"?"Provide liquidity":"Withdraw liquidity"}</h2></div><button className="icon-button" aria-label="Refresh pool" onClick={()=>void refresh()} disabled={loading}>{loading?"…":"↻"}</button></div>
          <div className="mode-tabs" role="tablist" aria-label="Exchange action">{(["swap","add","remove"] as Mode[]).map(m=><button key={m} role="tab" aria-selected={mode===m} className={mode===m?"selected":""} onClick={()=>{setMode(m);setTx(initialTx);}} disabled={busy}>{m==="swap"?"Swap":m==="add"?"Add liquidity":"Remove"}</button>)}</div>
          {mode==="swap"?<div className="swap-fields">
            <div className="amount-box"><div className="field-top"><label htmlFor="swap-input">You pay</label><button onClick={()=>setInput(formatAmount(balanceIn,18))} disabled={!isConnected||busy}>Balance: {snapshot&&isConnected?formatAmount(balanceIn):"—"} <strong>MAX</strong></button></div><div className="amount-row"><input id="swap-input" inputMode="decimal" autoComplete="off" placeholder="0.0" value={input} onChange={e=>setInput(e.target.value)} disabled={busy}/><span className="token-select"><TokenBadge name={reverse?"B2B":"B2A"}/>{reverse?"B2B":"B2A"}</span></div></div>
            <button className="reverse-button" aria-label="Reverse token direction" onClick={()=>{setReverse(!reverse);setInput("");}} disabled={busy}>↓</button>
            <div className="amount-box output"><div className="field-top"><label htmlFor="swap-output">You receive</label><span>Estimated output</span></div><div className="amount-row"><output id="swap-output">{quote?formatAmount(quote.out):"0.0"}</output><span className="token-select"><TokenBadge name={reverse?"B2A":"B2B"}/>{reverse?"B2A":"B2B"}</span></div></div>
          </div>:mode==="add"?<div className="liquidity-fields">
            <div className="amount-box"><label htmlFor="deposit-a">B2A maximum deposit</label><div className="amount-row"><input id="deposit-a" inputMode="decimal" placeholder="0.0" value={depositA} onChange={e=>setDepositA(e.target.value)} disabled={busy}/><TokenBadge name="B2A"/></div></div>
            <div className="amount-box"><label htmlFor="deposit-b">B2B maximum deposit</label><div className="amount-row"><input id="deposit-b" inputMode="decimal" placeholder="0.0" value={depositB} onChange={e=>setDepositB(e.target.value)} disabled={busy}/><TokenBadge name="B2B"/></div></div>
            <p className="helper-text">Only proportional amounts are deposited. {quote?"Estimated LP: "+formatAmount(quote.lp,12):"Enter both amounts to preview."}</p>
          </div>:<div className="exit-fields">
            <div className="amount-box"><span className="field-label">Your LP position</span><div className="position-amount">{snapshot&&isConnected?formatAmount(snapshot.lp,12):"—"}<small>B2-LP</small></div></div>
            <div className="percentage-buttons">{["2500","5000","7500","10000"].map(value=><button key={value} className={exitBps===value?"selected":""} onClick={()=>setExitBps(value)} disabled={busy}>{Number(value)/100}%</button>)}</div>
            <p className="helper-text">{quote?"Expected: "+formatAmount(quote.a)+" B2A + "+formatAmount(quote.b)+" B2B":"Connect a wallet with redeemable LP tokens."}</p>
          </div>}
          <div className="slippage-row"><label htmlFor="slippage">Slippage tolerance</label><select id="slippage" value={slippage} onChange={e=>setSlippage(e.target.value)} disabled={busy}><option value="10">0.1%</option><option value="50">0.5%</option><option value="100">1.0%</option></select></div>
          {mode==="swap"&&quote&&<div className="quote-details"><div><span>Minimum received</span><strong>{formatAmount(quote.minOut)} {reverse?"B2A":"B2B"}</strong></div><div><span>LP fee · 0.30%</span><strong>{formatAmount(fee,12)} {reverse?"B2B":"B2A"}</strong></div></div>}
          <button className="primary-action" disabled={!canAct} onClick={()=>void mainAction()}>{label}<span>↗</span></button>
          {(!configured||issue)&&<div className="inline-note" role="status">{!configured?"Contracts are being prepared. Transactions activate only after deployment verification.":issue}</div>}
          {tx.phase!=="idle"&&<div className={"transaction-status "+tx.phase} role="status" aria-live="polite"><span>{tx.phase==="confirmed"?"✓":tx.phase==="failed"?"!":"◌"}</span><div>{tx.message}{tx.hash&&<a href={explorer("tx",tx.hash)} target="_blank" rel="noreferrer">View transaction ↗</a>}</div></div>}
          <div className="panel-foot"><span className={"health-dot "+(verified?"healthy":"")}/>{verified?"Contract code checked · block "+snapshot?.block.toString():configured?"Checking contract deployment":"Awaiting deployment"}</div>
        </section>
        <aside className="details-column">
          <section className="pool-card"><div className="card-label"><span>ACTIVE POOL</span><span className="subtle-badge">V2 STYLE</span></div><div className="pool-title"><span className="stacked-tokens"><TokenBadge name="B2A"/><TokenBadge name="B2B"/></span><h3>B2A / B2B</h3></div><div className="reserve-row"><span>B2A reserve</span><strong>{snapshot?formatAmount(snapshot.rA):"—"}</strong></div><div className="reserve-row"><span>B2B reserve</span><strong>{snapshot?formatAmount(snapshot.rB):"—"}</strong></div><div className="pool-divider"/><div className="reserve-row"><span>Swap fee</span><strong className="accent">0.30%</strong></div><p>Trading fees stay in the pool and accrue proportionally to LPs.</p></section>
          <section className="wallet-card"><div className="card-label"><span>YOUR TEST ASSETS</span><span>↙</span></div><div className="wallet-asset"><span><TokenBadge name="B2A"/> B2A</span><strong>{snapshot&&isConnected?formatAmount(snapshot.a):"—"}</strong></div><button className="claim-button" disabled={!configured||!verified||!isConnected||wrongChain||busy||!!(snapshot?.nextA&&snapshot.nextA>BigInt(now))} onClick={()=>void perform("claimA")}>{claimLabel(snapshot?.nextA)} B2A <span>+</span></button><div className="wallet-asset"><span><TokenBadge name="B2B"/> B2B</span><strong>{snapshot&&isConnected?formatAmount(snapshot.b):"—"}</strong></div><button className="claim-button" disabled={!configured||!verified||!isConnected||wrongChain||busy||!!(snapshot?.nextB&&snapshot.nextB>BigInt(now))} onClick={()=>void perform("claimB")}>{claimLabel(snapshot?.nextB)} B2B <span>+</span></button><p>Test tokens are free to claim. Your wallet still needs {chainName} test ETH for gas.</p>{snapshot&&isConnected&&<div className="position-share">Your pool share <strong>{percentage(snapshot.lp,snapshot.supply)}%</strong></div>}</section>
        </aside>
      </section>
      <section className="protocol-section" id="protocol"><div><span className="eyebrow">VERIFY, THEN TRUST</span><h2>Open rules. Inspectable contracts.</h2><p>A fixed-fee constant-product AMM with no upgrade admin or privileged withdrawal.</p></div><div className="contract-links">{c?Object.entries(c).map(([name,value])=><a key={name} href={explorer("address",value)} target="_blank" rel="noreferrer"><span>{name==="tokenA"?"B2A":name==="tokenB"?"B2B":name}</span><code>{shorten(value)}</code><span>↗</span></a>):<div className="pending-contracts">Deployment addresses will appear after on-chain verification.</div>}</div></section>
      {receipts.length>0&&<section className="receipt-section"><h3>This session</h3>{receipts.map(r=><a key={r.hash} href={explorer("tx",r.hash)} target="_blank" rel="noreferrer"><span>✓ {r.label}</span><code>{shorten(r.hash)}</code><span>↗</span></a>)}</section>}
    </main>
    <footer><span>B2 AMM <span className="footer-divider">/</span> Built to be understood.</span><span>Synthetic test assets · AI-assisted self-assessment{deployment.auditedCommit?" · "+deployment.auditedCommit.slice(0,8):""}</span></footer>
  </div>;
}
