#!/usr/bin/env bash
# Regenerates the API reference in public/reference/ from Kai's source with
# `roc docs`, in kai.blu.cx's look:
#   public/reference/std/       Kai's standard plugin (what Kaifiles use)
#   public/reference/platform/  the plugin platform (for plugin authors)
#
#   ./reference.sh ~/src/kai [roc]
#
# roc defaults to the one on PATH; use the version in the checkout's
# .roc-version. `roc docs` also checks the links in doc comments; a broken
# one is reported (and should be fixed in Kai) but the pages are still kept.
set -euo pipefail
cd "$(dirname "$0")"
kai=$(realpath "$1")
roc=${2:-roc}
out=public/reference
theme=$(realpath reference-theme.css)
rm -rf "$out"
mkdir -p "$out"

for part in std:plugins/std/main.roc platform:platform/main.roc; do
  name=${part%%:*}
  entry=${part#*:}
  echo "roc docs $entry -> $out/$name"
  (cd "$kai" && "$roc" docs "$entry" --output="$OLDPWD/$out/$name") || echo "  (roc docs reported problems above; pages kept)"
  cat "$theme" >> "$out/$name/styles.css"
  # Fonts, and a bar back to the rest of the site, on every page.
  find "$out/$name" -name index.html -print0 | xargs -0 sed -i \
    -e 's#<link rel="stylesheet" href="\([./]*\)styles.css">#<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=EB+Garamond:wght@400;500\&amp;family=GFS+Didot\&amp;family=JetBrains+Mono:wght@400;500\&amp;display=swap"><link rel="stylesheet" href="\1styles.css">#' \
    -e 's#<body\([^>]*\)>#<body\1><header class="kai-bar"><a class="kai-mark" href="/">kαί</a><a href="/\#2">tour</a><a href="/docs/">docs</a><a href="/reference/std/" aria-current="page">api</a><a href="https://github.com/thebrandonlucas/kai/releases">changelog</a><a href="https://blu.cx/projects/kai/">blog</a><span class="kai-social"><a href="https://discord.gg/SrH3w5uAa3" aria-label="Discord" title="Discord"><img src="/icons/discord.svg" alt="" width="18" height="18"></a><a href="https://github.com/thebrandonlucas/kai" aria-label="GitHub" title="GitHub"><img src="/icons/github.svg" alt="" width="18" height="18"></a></span></header>#'
done

cat > "$out/index.html" <<'EOF'
<!doctype html>
<meta charset="utf-8">
<meta http-equiv="refresh" content="0; url=std/">
<a href="std/">Kai's API reference</a>
EOF
