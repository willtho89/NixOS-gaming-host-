#!/usr/bin/env bash

# Deployment script for gamingHost from a Mac (cross-architecture)
# Usage: ./deploy.sh <HOST> [USERNAME]

set -e

DEPLOY_HOST="${1:-}"
DEPLOY_USER="${2:-nixos}"

if [ -z "$DEPLOY_HOST" ]; then
  echo "Usage: ./deploy.sh <HOST> [USERNAME]" >&2
  echo "Example: ./deploy.sh gaming-pc.local alice" >&2
  exit 1
fi

echo "🚀 Deploying updates to ${DEPLOY_USER}@${DEPLOY_HOST}..."

# We use --build-host and --target-host because we're likely on an ARM Mac
# and the target is x86_64 Linux. This offloads the build to the target machine.
nix run nixpkgs#nixos-rebuild -- \
  --no-reexec \
  switch \
  --impure \
  --flake ".#gamingHost" \
  --build-host "${DEPLOY_USER}@${DEPLOY_HOST}" \
  --target-host "${DEPLOY_USER}@${DEPLOY_HOST}" \
  --sudo

echo "✅ Deployment finished successfully!"
