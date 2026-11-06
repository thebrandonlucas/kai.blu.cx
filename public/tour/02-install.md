# Install

Kai runs on Linux and needs
[Nix with flakes enabled](https://docs.determinate.systems/).

Download the archive for your system from the
[latest release](https://github.com/thebrandonlucas/kai/releases/latest),
check it against the release's `SHA256SUMS`, and put `kai` on your `PATH`:

```sh
tar -xzf kai-0.0.11-x86_64-linux.tar.gz
install -Dm755 kai ~/.local/bin/kai
kai --version
```

The archive holds only the `kai` binary. Kai reads your project's
`Kaifile.roc` with the [Roc](https://roc-lang.org) compiler, which it fetches
through Nix the first time if you don't have one.

Every command has help with examples: `kai --help`, `kai run --help`, …
