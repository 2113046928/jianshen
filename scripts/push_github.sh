#!/usr/bin/env bash
# 一键把工程推到 GitHub。
#
#   ./scripts/push_github.sh <github-username> [repo-name]
#
# 需要其中一种凭据：
#   1) 已安装 gh 并 gh auth login 过（最省事，会自动建仓库）
#   2) 已配置 SSH key 并能 ssh -T git@github.com
#   3) 设置环境变量 GITHUB_TOKEN（Personal Access Token，需要 repo 权限）
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

USER_NAME="${1:-}"
REPO_NAME="${2:-trainledger}"

if [[ -z "$USER_NAME" ]]; then
  echo "用法：./scripts/push_github.sh <github-username> [repo-name]" >&2
  exit 1
fi

if [[ ! -d .git ]]; then
  echo "==> 初始化仓库"
  git init -b main
  git add -A
  git commit -m "chore: 初始化练账工程"
fi

echo "==> 检查凭据"
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  echo "使用 gh CLI 创建仓库"
  gh repo create "$REPO_NAME" --private --source=. --remote=origin --push
  echo "完成：https://github.com/$USER_NAME/$REPO_NAME"
  exit 0
fi

if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  echo "使用 GITHUB_TOKEN 推送"
  git remote remove origin 2>/dev/null || true
  git remote add origin "https://${GITHUB_TOKEN}@github.com/${USER_NAME}/${REPO_NAME}.git"
  git push -u origin main
  # 推送后把 token 从 remote 里去掉，避免留在 .git/config
  git remote set-url origin "https://github.com/${USER_NAME}/${REPO_NAME}.git"
  echo "完成：https://github.com/$USER_NAME/$REPO_NAME"
  exit 0
fi

if ssh -o BatchMode=yes -o ConnectTimeout=5 -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
  echo "使用 SSH 推送（需要先在 GitHub 上建好空仓库 $REPO_NAME）"
  git remote remove origin 2>/dev/null || true
  git remote add origin "git@github.com:${USER_NAME}/${REPO_NAME}.git"
  git push -u origin main
  echo "完成：https://github.com/$USER_NAME/$REPO_NAME"
  exit 0
fi

cat >&2 <<'EOF'
没有可用的 GitHub 凭据。任选一种：

  A. 装 gh 并登录：
     brew install gh && gh auth login
     ./scripts/push_github.sh <用户名>

  B. 用 Personal Access Token：
     export GITHUB_TOKEN=ghp_xxx
     ./scripts/push_github.sh <用户名>

  C. 手动建仓库后推：
     git remote add origin git@github.com:<用户名>/trainledger.git
     git push -u origin main
EOF
exit 1
