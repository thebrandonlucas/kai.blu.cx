# kai.blu.cx

Kai's home page and guided tour, over Thomas Cole's *The Pastoral State*.

The page is laid out like a tiling window manager (Hyprland, Omarchy): a bar
with numbered workspaces on top, and one workspace per screen below. The first
is the painting with the wordmark; every tour step after it is a glass window
with its text, tiled with a Kaifile pane and a terminal pane when the step has
them.

**Moving around:** <kbd>↓</kbd> <kbd>j</kbd> <kbd>Space</kbd> next,
<kbd>↑</kbd> <kbd>k</kbd> previous, <kbd>1</kbd>–<kbd>9</kbd> and <kbd>0</kbd> a workspace,
<kbd>g</kbd> / <kbd>G</kbd> first and last, or scroll (it snaps), or click the
bar or the hint in the bottom right. `#n` in the URL opens workspace *n*
(`kai.blu.cx/#4`).

```sh
nix develop
./build.sh        # signals/ -> public/app.wasm, with roc-signals' runtime
```

`public/` is the whole site, served as static files by Caddy on the VPS that
also serves blu.cx.

## The app

The home page and tour, the guides and the changelog are one app in
[Roc](https://www.roc-lang.org) on
[roc-signals](https://github.com/lukewilliamboswell/roc-signals) 0.5.0, in
`signals/`; it shows the page its path names. `build.sh` runs its tests
(`roc test signals/main.roc`), builds it for the browser (`public/app.wasm`)
and downloads the release's `runtime.mjs` and `worker.mjs`, checked against
`signals/runtime.lock.json`. The flake gives the Roc nightly the release was
built with. Each page loads `site-app.mjs`, which mounts the app on `#app`.

What roc-signals doesn't model is in `public/site-ports.mjs`: scrolling the
tour and following its scroll, keys pressed anywhere on the page, and
`<kai-html>`, which shows the HTML of Markdown rendered by
`signals/Markdown.roc`. Gaps in roc-signals found while porting are drafted
in [roc-issues](https://github.com/thebrandonlucas/roc-issues/tree/master/roc-signals);
those filed upstream are in its
[archive](https://github.com/thebrandonlucas/roc-issues/tree/master/archive).

Caddy has to serve `app.wasm` as `application/wasm` and the `.mjs` files as
`text/javascript`.

## Writing the tour

The tour is in `public/tour/` and is fetched when the page loads, so editing it
needs no rebuild:

- `tour.json` lists the steps in order. Each has an `id` (shown in the window
  title), a `title` (the bar's label), a `markdown` file and, optionally, a
  `kaifile` (a Roc file, highlighted, with its header folded) and a `terminal`
  file, shown as tabs in one window (Tab switches); `"open": "terminal"`
  makes the terminal the first tab.
- **Markdown** is GitHub-flavoured (tables included); inline HTML such as
  `<kbd>` works.
- **Terminal files** are recorded sessions: a line starting with `$ ` is a
  command, shown after a gold prompt; everything else is output. The ones here
  were recorded with kai 0.0.11 on 2026-11-06 (`kai init`, `check`, `update`,
  `run`, `shell`, `build`, `workflow`), with `/tmp` paths shortened to `~/cow`
  and `~/hello`, exit-code lines and Guix's progress bar removed.


## Docs and reference

- **Guides**, at `/docs/` (`public/docs/index.html`, `signals/Docs.roc`): a
  file tree of the pages beside a reading window.
  The pages are in `public/docs/pages/`: `docs.json` lists the sections and
  their pages, each page is `<slug>.md`, and `/docs/#<slug>` opens one.
  Keys: <kbd>j</kbd>/<kbd>k</kbd> scroll, <kbd>h</kbd>/<kbd>l</kbd> the
  previous and next page, <kbd>g</kbd>/<kbd>G</kbd> top and bottom. They were
  first split from Kai's README and `docs/plugin.md` at v0.0.11.
- **API reference**, at `/reference/std/` and `/reference/platform/`,
  generated from Kai's source by `roc docs` and restyled:

  ```sh
  ./reference.sh ~/src/kai "$(which roc)"   # use the checkout's .roc-version
  ```

  `reference-theme.css` is appended to each reference's stylesheet, and a bar
  linking back to the site is added to every page. Run it for each release.

## Editing and preview

Git is the only source of the content: the tour (`public/tour/`), the guides
(`public/docs/pages/`) and the blog's posts (`public/blog/posts/`) are files in
this repo, and every change is a commit on the `tour` branch.

Each commit there is on the preview, <https://kai.internal.blu.cx> (your own
devices only), within about half a minute: blu-tower's `kai-preview` service
checks the branch every 15 seconds, builds the new commit in a separate
worktree (`../kai.nix.fun-preview`, so uncommitted edits never show) and copies
the build to the preview. It also takes commits pushed to the forge's `tour`
branch (from a laptop: `rad clone`, edit, push), fast-forward only and only
while this checkout is clean.

From a phone, ask an agent in Paseo working in this repo to make the change
and commit it.

Publishing stays a separate step: merge `tour` into `main` and deploy (below).

## Background

The background is Thomas Cole, *The Course of Empire: The Arcadian or
Pastoral State* (1834), public domain, from
[Wikimedia Commons](https://commons.wikimedia.org/wiki/File:Cole_Thomas_The_Course_of_Empire_The_Arcadian_or_Pastoral_State_1836.jpg).
`public/images/` holds it at 1920, 2560 and 3840 pixels wide (AVIF, WebP,
JPEG) and as a tiny blurred placeholder; `styles.css` picks the size by
screen.

## Deploying

```sh
nix develop
./deploy.sh
```

builds, copies `public/` to a new release on the VPS and switches
`/var/www/kai/current` to it in one step (Caddy serves that link). The
last five releases stay for rolling back. Needs a machine whose SSH key
the VPS accepts (blu-tower's, as root).

The home page's install command is `curl -fsSL https://kai.blu.cx/install.sh | sh`,
so the VPS's Caddy site for kai.blu.cx (`/etc/caddy/kai.caddy`) needs

```caddy
redir /install.sh https://github.com/thebrandonlucas/kai/releases/latest/download/install.sh 302
```

(the preview on the tailnet doesn't have it).
