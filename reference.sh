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
  cp public/favicon.svg "$out/$name/favicon.svg"
  # Fonts, and the site bar (reference-bar.html, the static twin of
  # SiteBar.elm, with its number keys), on every page.
  find "$out/$name" -name index.html -print0 | xargs -0 sed -i \
    -e 's#<link rel="stylesheet" href="\([./]*\)styles.css">#<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=EB+Garamond:wght@400;500\&amp;family=GFS+Didot\&amp;family=JetBrains+Mono:wght@400;500\&amp;display=swap"><link rel="stylesheet" href="\1styles.css">#'
  BAR=$(tr -d '\n' < reference-bar.html) \
    find "$out/$name" -name index.html -exec perl -pi -e 's/<body([^>]*)>/<body$1>$ENV{BAR}/' {} +
done

cat > "$out/index.html" <<'EOF'
<!doctype html>
<meta charset="utf-8">
<meta http-equiv="refresh" content="0; url=std/">
<a href="std/">Kai's API reference</a>
EOF
