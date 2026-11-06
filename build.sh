#!/usr/bin/env bash
# Builds the site into public/: Elm compiles src/Main.elm (the home page and
# tour) to public/elm.js and src/Docs.elm (the guides) to public/docs.js.
# Run inside `nix develop` (or anywhere with elm 0.19.2 on the PATH).
# The API reference in public/reference is made by reference.sh.
set -euo pipefail
cd "$(dirname "$0")"
elm make src/Main.elm --optimize --output public/elm.js
elm make src/Docs.elm --optimize --output public/docs.js
