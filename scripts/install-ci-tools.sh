#!/usr/bin/env bash
set -euo pipefail
tool_dir="$PWD/.ci-tools"
mkdir -p "$tool_dir"
curl -fLsS https://github.com/foundry-rs/foundry/releases/download/v1.8.1/foundry_v1.8.1_linux_amd64.tar.gz -o "$tool_dir/foundry.tar.gz"
tar -xzf "$tool_dir/foundry.tar.gz" -C "$tool_dir"
(cd "$tool_dir" && printf '%s  %s
' e4d66ae9c430d6070da2ee4f5c71f601f822a1ddad044a06da5f3da6baeba950 forge 90a02a6b3a002f0a178f96deb4745d086fa554eca385743f78dd9e1610735dee cast 9e58b59ff599ed6214ee3beeb8a4f7080ecad6a65b5b43d3a4fa4653693ee9cd anvil | sha256sum -c -)
curl -fLsS https://github.com/cyfrin/aderyn/releases/download/aderyn-v0.6.8/aderyn-x86_64-unknown-linux-gnu.tar.xz -o "$tool_dir/aderyn.tar.xz"
mkdir -p "$tool_dir/aderyn-dist"
tar -xJf "$tool_dir/aderyn.tar.xz" -C "$tool_dir/aderyn-dist"
aderyn_binary=$(find "$tool_dir/aderyn-dist" -type f -name aderyn -print -quit)
test -n "$aderyn_binary"
printf '%s  %s
' a268d616826901e17717b1bc6368d8b2c063045a46fb99a0c0f657f102d977ca "$aderyn_binary" | sha256sum -c -
cp "$aderyn_binary" "$tool_dir/aderyn"
echo "$tool_dir" >> "$GITHUB_PATH"
python3 -m venv .audit-venv
.audit-venv/bin/pip install -r scripts/requirements-audit.txt
echo "$PWD/.audit-venv/bin" >> "$GITHUB_PATH"
