# kai.blu.cx

Kai's home page: the wordmark, the tagline and where to find the project
([Kai on GitHub](https://github.com/thebrandonlucas/kai)).

```sh
nix develop
./build.sh        # src/Main.elm -> public/elm.js
```

`public/` is the whole site, served as static files by Caddy on the VPS that
also serves blu.cx.

The background is Thomas Cole, *The Course of Empire: The Arcadian or
Pastoral State* (1834), public domain, from
[Wikimedia Commons](https://commons.wikimedia.org/wiki/File:Cole_Thomas_The_Course_of_Empire_The_Arcadian_or_Pastoral_State_1836.jpg).
`public/images/` holds it at 1920, 2560 and 3840 pixels wide (AVIF, WebP,
JPEG) and as a tiny blurred placeholder; `styles.css` picks the size by
screen.

The source was recovered on 2026-10-12 from the deployed site (whose Elm
build was unminified); the page is unchanged apart from the background.

## Deploying

```sh
nix develop
./deploy.sh
```

builds, copies `public/` to a new release on the VPS and switches
`/var/www/kai/current` to it in one step (Caddy serves that link). The
last five releases stay for rolling back. Needs a machine whose SSH key
the VPS accepts (blu-tower's, as root).
