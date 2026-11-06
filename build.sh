#!/usr/bin/env bash
# Builds the site into public/. Run inside `nix develop`.
#   src/Main.elm       -> public/elm.js        the home page and tour
#   src/Docs.elm       -> public/docs.js       the guides
#   src/Changelog.elm  -> public/changelog.js  the changelog
#   blog.sh                                    the blog and its feed
# The API reference in public/reference is made by reference.sh.
set -euo pipefail
cd "$(dirname "$0")"
elm make src/Main.elm --optimize --output public/elm.js
elm make src/Docs.elm --optimize --output public/docs.js
elm make src/Changelog.elm --optimize --output public/changelog.js
./blog.sh
