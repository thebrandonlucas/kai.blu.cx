#!/usr/bin/env bash
# Builds the site into public/: Elm compiles src/Main.elm to public/elm.js.
# Run inside `nix develop` (or anywhere with elm 0.19.2 on the PATH).
set -euo pipefail
cd "$(dirname "$0")"
elm make src/Main.elm --optimize --output public/elm.js
