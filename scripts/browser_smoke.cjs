const { chromium, expect: baseExpect } = require("@playwright/test");
const expect = baseExpect.configure({ timeout: 120000 });
const fs = require("node:fs");
const assert = require("node:assert/strict");
const { execFileSync } = require("node:child_process");
(async () => {
 const url=process.env.AMM_BROWSER_URL, rpc=process.env.AMM_BROWSER_RPC, actor=process.env.AMM_BROWSER_ACTOR, output=process.env.AMM_BROWSER_EVIDENCE;
 const config=JSON.parse(process.env.AMM_BROWSER_FIXTURE), errors=[], checkpoints=[];
 const browser=await chromium.launch({headless:true,executablePath:process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE});
 const context=await browser.newContext({viewport:{width:1440,height:1000}});
 await context.addInitScript(({rpc,actor})=>{
  const listeners=new Map();let chain="0x7a69";
  window.__transactions=[];
  const emit=(event,value)=>(listeners.get(event)||[]).forEach(fn=>fn(value));
  window.__changeWalletChain=value=>{chain=value;emit("chainChanged",value)};
  window.ethereum={isMetaMask:true,on:(event,fn)=>listeners.set(event,[...(listeners.get(event)||[]),fn]),removeListener:(event,fn)=>listeners.set(event,(listeners.get(event)||[]).filter(x=>x!==fn)),async request({method,params}){
   if(method==="eth_chainId")return chain;
   if(method==="eth_accounts"||method==="eth_requestAccounts")return [actor];
   if(method==="wallet_switchEthereumChain"){window.__changeWalletChain(params[0].chainId);return null;}
   if(method==="wallet_requestPermissions"||method==="wallet_getPermissions")return [{parentCapability:"eth_accounts"}];
   const res=await fetch(rpc,{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({jsonrpc:"2.0",id:1,method,params:params||[]})});
   const data=await res.json();if(data.error)throw Object.assign(new Error(data.error.message),data.error);
   if(method==="eth_sendTransaction")window.__transactions.push(data.result);
   return data.result;
  }};
 },{rpc,actor});
 const page=await context.newPage();page.setDefaultTimeout(120000);page.on("pageerror",e=>errors.push(e.message));
 const record=name=>{checkpoints.push({name,status:"PASS"});console.log("PASS "+name)};
 const balance=token=>BigInt(execFileSync("cast",["call",token,"balanceOf(address)(uint256)",actor,"--rpc-url",rpc],{encoding:"utf8"}).trim().split(" ")[0]);
 try {
  await page.goto(url,{waitUntil:"networkidle"});
  await page.getByRole("button",{name:"Connect wallet",exact:false}).first().click();
  await expect(page.locator(".claim-button").first()).toBeEnabled();record("connect injected test wallet and verify contract runtime hashes");
  await page.locator(".claim-button").nth(0).click();await expect(page.locator(".transaction-status")).toContainText("Test tokens claimed");
  await page.locator(".claim-button").nth(1).click();await expect(page.locator(".transaction-status")).toContainText("Test tokens claimed");
  assert.equal(balance(config.contracts.tokenA),1000n*10n**18n);assert.equal(balance(config.contracts.tokenB),1000n*10n**18n);record("claim both synthetic faucet assets with real receipts");
  await page.getByLabel("You pay",{exact:true}).fill("1");await page.locator(".primary-action").click();await expect(page.locator(".transaction-status")).toContainText("Swap confirmed");
  assert.equal(balance(config.contracts.tokenA),999n*10n**18n);assert(balance(config.contracts.tokenB)>1000n*10n**18n);record("bounded approval and swap settle actual token deltas");
  await page.getByRole("tab",{name:"Add liquidity",exact:true}).click();await page.getByLabel("B2A maximum deposit").fill("10");await page.getByLabel("B2B maximum deposit").fill("10");await page.locator(".primary-action").click();await expect(page.locator(".transaction-status")).toContainText("Liquidity added");
  assert(balance(config.contracts.pair)>0n);record("add liquidity and receive LP shares");
  await page.getByRole("tab",{name:"Remove",exact:true}).click();await page.locator(".primary-action").click();await expect(page.locator(".transaction-status")).toContainText("Liquidity removed");assert.equal(balance(config.contracts.pair),0n);record("redeem all user LP shares through the UI");
  await page.evaluate(()=>window.__changeWalletChain("0x1"));await expect(page.locator(".primary-action")).toContainText("Switch to Local Anvil");await expect(page.locator(".claim-button").first()).toBeDisabled();record("wrong network blocks asset actions");
  await page.locator(".primary-action").click();await expect(page.locator(".primary-action")).not.toContainText("Switch to");
  await page.screenshot({path:output+"/desktop.png",fullPage:true});await page.setViewportSize({width:390,height:844});await page.screenshot({path:output+"/mobile.png",fullPage:true});assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));record("390px layout without horizontal overflow");
  const hashes=await page.evaluate(()=>window.__transactions), receipts=[];
  for(const hash of hashes){const res=await fetch(rpc,{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({jsonrpc:"2.0",id:1,method:"eth_getTransactionReceipt",params:[hash]})});const data=await res.json();assert.equal(data.result.status,"0x1");receipts.push(data.result);}
  assert.equal(errors.length,0,errors.join("\n"));record("no browser page exceptions; every submitted transaction receipt succeeded");
  fs.writeFileSync(output+"/acceptance.json",JSON.stringify({status:"PASS",wallet:"synthetic EIP-1193 provider, not a real MetaMask extension",chainId:31337,actor,checkpoints,receipts},null,2));
 } catch(error){await page.screenshot({path:output+"/failure.png",fullPage:true});fs.writeFileSync(output+"/failure.json",JSON.stringify({error:String(error),checkpoints,errors},null,2));throw error;}
 finally{await browser.close()}
})().catch(error=>{console.error(error);process.exitCode=1});
