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
./build.sh        # src/Main.elm -> public/elm.js
```

`public/` is the whole site, served as static files by Caddy on the VPS that
also serves blu.cx.

## Writing the tour

The tour is in `public/tour/` and is fetched when the page loads, so editing it
needs no rebuild:

- `tour.json` lists the steps in order. Each has an `id` (shown in the window
  title), a `title` (the bar's label), a `markdown` file and, optionally, a
  `kaifile` (a Roc file shown with line numbers) and a `terminal` file.
- **Markdown** is GitHub-flavoured (tables included); inline HTML such as
  `<kbd>` works.
- **Terminal files** are recorded sessions: a line starting with `$ ` is a
  command, shown after a gold prompt; everything else is output. The ones here
  were recorded with kai 0.0.11 on 2026-11-06 (`kai init`, `check`, `update`,
  `run`, `shell`, `build`, `workflow`), with `/tmp` paths shortened to `~/cow`
  and `~/hello`, exit-code lines and Guix's progress bar removed.

## Preview

Before deploying, the build is previewed on the tailnet at
<https://kai.internal.blu.cx> (your own devices only): on blu-tower,

```sh
rsync -a --delete dev@10.77.0.1:src/kai.nix.fun/public/ /srv/kai-preview/
```

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
