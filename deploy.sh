#!/usr/bin/env bash
# Builds the site and copies public/ to the VPS that serves kai.nix.fun (the
# same one as blu.cx), replacing what was there. Caddy serves the files as
# they are, so there is nothing to restart.
#   KAI_DEPLOY=user@host:/path/to/kai.nix.fun ./deploy.sh
# Run inside `nix develop` (elm), from a machine whose SSH key the VPS accepts.
set -euo pipefail
cd "$(dirname "$0")"
: "${KAI_DEPLOY:?set KAI_DEPLOY=user@host:/path (the folder Caddy serves for kai.nix.fun)}"
./build.sh
rsync -rlvz --delete --chmod=D755,F644 public/ "$KAI_DEPLOY/"
code=$(curl -s -o /dev/null -w "%{http_code}" https://kai.nix.fun/images/pastoral-placeholder.webp)
[ "$code" = 200 ] && echo "Live: https://kai.nix.fun" || { echo "kai.nix.fun answers $code for the new images; check the path"; exit 1; }
