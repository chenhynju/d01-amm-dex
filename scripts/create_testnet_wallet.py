#!/usr/bin/env python3
"""Create one dedicated testnet signer; encrypted keystore + Windows-current-user DPAPI password.
No private key/password is printed, placed in argv or written in plaintext.
"""
from pathlib import Path
import os,json,secrets,subprocess
from eth_account import Account
from eth_utils import to_checksum_address
root=Path(__file__).resolve().parents[1]
home=Path.home()
keyfile=home/".foundry/keystores/b2-amm-base-sepolia.json"
public=root/"deployments/base-sepolia-wallet.json"
if keyfile.exists():
    data=json.loads(keyfile.read_text())
    address=to_checksum_address("0x"+data["address"].removeprefix("0x"))
    print(json.dumps({"status":"EXISTING","address":address,"keystore":str(keyfile)}))
    raise SystemExit(0)
account=Account.create()
password=secrets.token_urlsafe(48)
encrypted=Account.encrypt(account.key,password,kdf="scrypt")
assert Account.decrypt(encrypted,password)==account.key
ps=r"""
Add-Type -AssemblyName System.Security
$data=[Console]::In.ReadToEnd() | ConvertFrom-Json
$folder=Join-Path $env:LOCALAPPDATA 'B2AMM'
[IO.Directory]::CreateDirectory($folder) | Out-Null
$secretBytes=[Text.Encoding]::UTF8.GetBytes($data.password)
$protected=[Security.Cryptography.ProtectedData]::Protect($secretBytes,$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)
$roundtrip=[Security.Cryptography.ProtectedData]::Unprotect($protected,$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)
if([Convert]::ToBase64String($secretBytes) -ne [Convert]::ToBase64String($roundtrip)){throw 'DPAPI roundtrip failed'}
$passFile=Join-Path $folder 'base-sepolia-password.dpapi'
$keyFile=Join-Path $folder 'base-sepolia-keystore.json'
if((Test-Path -LiteralPath $passFile) -or (Test-Path -LiteralPath $keyFile)){throw 'Existing wallet backup: refusing overwrite'}
[IO.File]::WriteAllBytes($passFile,$protected)
[IO.File]::WriteAllText($keyFile,($data.keystore | ConvertTo-Json -Depth 12),[Text.UTF8Encoding]::new($false))
Write-Output 'DPAPI_SAVED'
"""
result=subprocess.run(
 ["/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe","-NoProfile","-NonInteractive","-Command",ps],
 input=json.dumps({"password":password,"keystore":encrypted}),text=True,capture_output=True)
if result.returncode or "DPAPI_SAVED" not in result.stdout:
    raise RuntimeError("Windows protected backup failed; no Linux signer written. "+result.stderr[:400])
keyfile.parent.mkdir(parents=True,exist_ok=True,mode=0o700)
keyfile.write_text(json.dumps(encrypted))
keyfile.chmod(0o600)
public.parent.mkdir(exist_ok=True)
record={"network":"Base Sepolia","chainId":84532,"address":account.address,
        "purpose":"B2 AMM dedicated testnet deployer; no mainnet use",
        "storage":"encrypted Foundry-compatible keystore in WSL; password protected by Windows current-user DPAPI",
        "linux_keystore":str(keyfile),
        "windows_backup_directory":"%LOCALAPPDATA%/B2AMM",
        "funding_status":"NOT CHECKED","private_key_exported":False}
public.write_text(json.dumps(record,indent=2))
print(json.dumps({"status":"CREATED","address":account.address,"chainId":84532,"encryption":"scrypt keystore + DPAPI password","public_record":str(public)}))
