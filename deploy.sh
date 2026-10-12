#!/usr/bin/env bash
# Builds the site and puts it live on the VPS that serves kai.nix.fun (the
# same one as blu.cx). Caddy serves /var/www/kai/current, a link to one of
# /var/www/kai/releases/*: the build is copied to a new release, then the link
# is switched in one step, so nobody sees a half-copied site. The last five
# releases stay, for rolling back: point the link at an older one.
#   ./deploy.sh                          (KAI_HOST defaults to root@216.155.158.213)
# Run inside `nix develop`, from a machine whose SSH key the VPS accepts.
set -euo pipefail
cd "$(dirname "$0")"
host=${KAI_HOST:-root@216.155.158.213}
base=/var/www/kai
release="$base/releases/release.$(date -u +%Y%m%d%H%M%S).$(git rev-parse --short HEAD)"

./build.sh
ssh "$host" "mkdir -p "
rsync -rlz --chmod=D755,F644 public/ "$host:$release/"
ssh "$host" "ln -sfn  /current.new && mv -T /current.new /current &&
  cd /releases && ls -1dt release.* | tail -n +6 | xargs -r rm -rf"

code=$(curl -s -o /dev/null -w "%{http_code}" https://kai.nix.fun/images/pastoral-placeholder.webp)
if [ "$code" = 200 ]; then echo "Live: https://kai.nix.fun ($release)"; else echo "kai.nix.fun answers $code for the new files"; exit 1; fi
