#!/usr/bin/env bash
# Builds the site into public/. Run inside `nix develop`.
#   signals/ (Roc, on roc-signals)  -> public/app.wasm     the home page and tour, the guides
#                                                          and the changelog, by the page's path
#   signals/runtime.lock.json       -> public/runtime.mjs  roc-signals' runtime and its worker,
#                                      public/worker.mjs   downloaded and checked by SHA-256
#   blog.sh                                                the blog and its feed
# The API reference in public/reference is made by reference.sh.
set -euo pipefail
cd "$(dirname "$0")"

roc test signals/main.roc
roc build --target=wasm32 --opt=size signals/main.roc --output=public/app.wasm

for file in runtime.mjs worker.mjs; do
  url=$(jq -r ".files[\"$file\"].url" signals/runtime.lock.json)
  sha256=$(jq -r ".files[\"$file\"].sha256" signals/runtime.lock.json)
  if ! echo "$sha256  public/$file" | sha256sum --check --status 2>/dev/null; then
    curl -fsSL "$url" -o "public/$file.part"
    echo "$sha256  public/$file.part" | sha256sum --check --quiet
    mv "public/$file.part" "public/$file"
  fi
done

./blog.sh
