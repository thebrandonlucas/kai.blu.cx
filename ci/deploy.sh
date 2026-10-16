#!/usr/bin/env bash
# Deploys kai.blu.cx from forge CI (the forge microVM on blu-tower) on every
# push to main, with ./deploy.sh and the CI job's deploy key, as kai-deploy:
# a user on the VPS that owns /var/www/kai and nothing else. Commits that are
# not the head of the default branch (patches) are built but not deployed.
set -euo pipefail

rid="z4HqYivXLr2XhKPQnHnNyEFutR3r1"
forge="https://forge.tail42aee1.ts.net"
key="/var/lib/ci-secrets/deploy_ed25519"
here="$(cd "$(dirname "$0")" && pwd)"

# CI jobs get no writable home; elm keeps its packages under it.
export HOME="$(mktemp -d)"
export XDG_CACHE_HOME="$HOME/.cache"
# deploy.sh and rsync call plain `ssh`: give it CI's key and the VPS's
# pinned host key (ci/known_hosts).
bin="$(mktemp -d)"
printf '#!/bin/sh\nexec %s -i %s -o BatchMode=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=%s "$@"\n' \
  "$(command -v ssh)" "$key" "$here/known_hosts" > "$bin/ssh"
chmod +x "$bin/ssh"
export PATH="$bin:$PATH"

head="$(curl -fsS "$forge/api/v1/repos/rad:$rid" | jq -r '.payloads["xyz.radicle.project"].meta.head')"
if [ "$(git rev-parse HEAD)" != "$head" ]; then
  nix develop -c ./build.sh
  echo "Built $(git rev-parse --short HEAD); not the default branch head, so not deploying."
  exit 0
fi

export KAI_HOST="kai-deploy@216.155.158.213"
exec nix develop -c ./deploy.sh
