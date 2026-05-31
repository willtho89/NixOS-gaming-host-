#!/usr/bin/env bash

# Deployment script for gamingHost from a Mac (cross-architecture)
# Usage: ./deploy.sh <HOST> [USERNAME]

set -euo pipefail

DEPLOY_HOST="${1:-}"
DEPLOY_USER="${2:-nixos}"
DEPLOY_TARGET="${DEPLOY_USER}@${DEPLOY_HOST}"
REPO_URL="$(git remote get-url origin 2>/dev/null || true)"
CURRENT_BRANCH="$(git branch --show-current 2>/dev/null || printf 'main')"
LOCAL_SETTINGS_PATH="hosts/gamingHost/local-settings.nix"

if [ -z "$DEPLOY_HOST" ]; then
  echo "Usage: ./deploy.sh <HOST> [USERNAME]" >&2
  echo "Example: ./deploy.sh gaming-pc.local alice" >&2
  exit 1
fi

echo "🚀 Deploying updates to ${DEPLOY_USER}@${DEPLOY_HOST}..."

if [ -n "$REPO_URL" ]; then
  echo "📦 Syncing /etc/nixos to ${REPO_URL} (${CURRENT_BRANCH})..."
  ssh "$DEPLOY_TARGET" "bash -lc 'set -euo pipefail; tmpdir=\$(mktemp -d); trap \"rm -rf \$tmpdir\" EXIT; nix shell nixpkgs#git -c git clone --branch "${CURRENT_BRANCH}" --single-branch "${REPO_URL}" \"\$tmpdir/repo\"; sudo rm -rf /etc/nixos; sudo mkdir -p /etc; sudo mv \"\$tmpdir/repo\" /etc/nixos; sudo chown -R ${DEPLOY_USER}:users /etc/nixos'"
fi

if [ -f "$LOCAL_SETTINGS_PATH" ]; then
  echo "🔐 Syncing local-settings.nix to the host..."
  ssh "$DEPLOY_TARGET" 'sudo mkdir -p /etc/nixos/hosts/gamingHost && sudo chown -R "'$DEPLOY_USER'":users /etc/nixos/hosts/gamingHost'
  scp "$LOCAL_SETTINGS_PATH" "$DEPLOY_TARGET:/etc/nixos/hosts/gamingHost/local-settings.nix"
fi

# We use --build-host and --target-host because we're likely on an ARM Mac
# and the target is x86_64 Linux. This offloads the build to the target machine.
nix run nixpkgs#nixos-rebuild -- \
  --no-reexec \
  switch \
  --impure \
  --flake ".#gamingHost" \
  --build-host "${DEPLOY_TARGET}" \
  --target-host "${DEPLOY_TARGET}" \
  --sudo

echo "✅ Deployment finished successfully!"
