#!/bin/bash
set -e
cd "/Users/d/WorkBuddy/2026-11-19-17-14-07/WheelVolume"

# 1) 自动探测可用本地代理端口，解决 git push 超时（v2rayN 常见 10808）
PROXY=""
for port in 10808 10809 7890 7897 56674; do
  if nc -z -w 1 127.0.0.1 "$port" 2>/dev/null; then
    if curl -sS --proxy "http://127.0.0.1:$port" -o /dev/null \
         --connect-timeout 5 https://github.com >/dev/null 2>&1; then
      PROXY="http://127.0.0.1:$port"
      echo "Using proxy: $PROXY"
      break
    fi
  fi
done
if [ -n "$PROXY" ]; then
  git config --local http.proxy "$PROXY"
  git config --local https.proxy "$PROXY"
else
  echo "No working proxy found; trying direct connection."
  git config --local --unset http.proxy 2>/dev/null || true
  git config --local --unset https.proxy 2>/dev/null || true
fi

# 2) 若提供 Token，配置临时凭据（用法: GH_TOKEN=xxx bash publish.sh）
if [ -n "${GH_TOKEN:-}" ]; then
  git config --local credential.helper \
    '!f() { printf "username=x-access-token\npassword=%s\n" "$GH_TOKEN"; }; f'
fi

# 3) 幂等处理：若仓库未初始化则初始化；已有提交则跳过
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  git init
fi
git config user.name "googlemr"
git config user.email "72286699+googlemr@users.noreply.github.com"

# 确保远端存在
git remote remove origin 2>/dev/null || true
git remote add origin https://github.com/googlemr/WheelVolume.git
git branch -M main

# 若有未提交改动，提交；若无则跳过
if ! git diff-index --quiet HEAD -- 2>/dev/null; then
  git add -A
  git commit -m "release: v1.0.0" || true
fi

# 4) 推送（历史已在本地合并，快进推送）
git push -u origin main

# 5) 打 tag 并推送（若已存在则跳过）
if ! git rev-parse -q --verify refs/tags/v1.0.0 >/dev/null; then
  git tag -a v1.0.0 -m "WheelVolume v1.0.0"
fi
git push origin v1.0.0

echo "DONE: repository pushed and tag v1.0.0 created. CI will build and publish the Release automatically."
