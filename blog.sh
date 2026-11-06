#!/usr/bin/env bash
# Builds the blog from public/blog/posts/*.md (edited in Syncthing,
# kai.blu.cx/blog): a static page per post at /blog/<slug>/, the list at
# /blog/, and an Atom feed at /blog/feed.xml (also /feed.xml). Static, so
# search engines and feed readers get the text; a post with `original:`
# names that address as canonical and links to it.
# Front matter: title, date (YYYY-MM-DD), description, original.
# Needs pandoc (in `nix develop`).
set -euo pipefail
cd "$(dirname "$0")"
site="https://kai.blu.cx"
posts=public/blog/posts
out=public/blog
[ -d "$posts" ] || { echo "no $posts; skipping the blog"; exit 0; }

field() { # field <file> <name>: a front-matter value, quotes removed
  awk -v k="$2" '/^---$/{n++; next} n==1 && $0 ~ "^"k":" { sub("^"k":[ ]*", ""); gsub(/^"|"$/, ""); print; exit }' "$1"
}
xml() { sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'; }
long_date() { date -d "$1" "+%B %-d, %Y"; }

# Newest first.
mapfile -t files < <(for f in "$posts"/*.md; do echo "$(field "$f" date) $f"; done | sort -r | cut -d' ' -f2-)

# The bar, as in SiteBar.elm, with blog current.
bar=$(sed -e 's#data-key="4"#data-key="4" aria-current="page"#' -e 's#class="bar-link" href="/blog/"#class="bar-link bar-link-active" href="/blog/"#' site-bar.html | tr -d '\n')

rm -rf "$out"/images && cp -r "$posts"/images "$out"/images 2>/dev/null || true
find "$out" -mindepth 1 -maxdepth 1 -type d ! -name posts ! -name images -exec rm -rf {} +

entries="" list="" updated=""
for i in "${!files[@]}"; do
  f=${files[$i]}
  slug=$(basename "$f" .md)
  title=$(field "$f" title)
  date=$(field "$f" date)
  description=$(field "$f" description)
  original=$(field "$f" original)
  [ -n "$updated" ] || updated="${date}T00:00:00Z"
  mkdir -p "$out/$slug"
  pandoc -f gfm+yaml_metadata_block -t html5 --template=templates/post.html \
    -V bar="$bar" -V slug="$slug" -V long_date="$(long_date "$date")" \
    -V canonical="${original:-$site/blog/$slug/}" \
    "$f" -o "$out/$slug/index.html"
  list+="<li><a class=\"post-link\" href=\"/blog/$slug/\"><span class=\"post-date\">$date</span><span class=\"post-title\">$(printf '%s' "$title" | xml)</span></a>"
  [ -n "$description" ] && list+="<p class=\"post-summary\">$(printf '%s' "$description" | xml)</p>"
  list+="</li>"
  body=$(pandoc -f gfm+yaml_metadata_block -t html5 "$f" | sed -e "s#src=\"/#src=\"$site/#g" -e "s#href=\"/#href=\"$site/#g")
  entries+="<entry><title>$(printf '%s' "$title" | xml)</title><link href=\"$site/blog/$slug/\"/><id>$site/blog/$slug/</id><published>${date}T00:00:00Z</published><updated>${date}T00:00:00Z</updated>"
  [ -n "$description" ] && entries+="<summary>$(printf '%s' "$description" | xml)</summary>"
  entries+="<content type=\"html\"><![CDATA[$body]]></content></entry>"$'\n'
done

pandoc -f html -t html5 --template=templates/blog-index.html -V bar="$bar" -V list="$list" /dev/null -o "$out/index.html"

cat > "$out/feed.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
<title>Kai</title>
<subtitle>The Kai blog: devlogs and articles on Kai, a friendly frontend for determinate computing.</subtitle>
<link href="$site/blog/"/>
<link rel="self" href="$site/blog/feed.xml"/>
<id>$site/blog/</id>
<updated>$updated</updated>
<author><name>Brandon Lucas</name></author>
$entries</feed>
EOF
cp "$out/feed.xml" public/feed.xml
echo "blog: ${#files[@]} posts"
