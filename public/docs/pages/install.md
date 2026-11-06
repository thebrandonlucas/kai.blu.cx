# Install

Kai runs on Linux and needs
[Nix with flakes enabled](https://nixos.org/download).

Install the latest release into `~/.local/bin`:

```sh
curl -fsSL https://github.com/thebrandonlucas/kai/releases/latest/download/install.sh | sh
```

The [script](install.sh) checks the download against the release's
`SHA256SUMS`. When neither Nix nor Guix is installed, it asks whether to
install Nix with the official installer and enable flakes; not at a
terminal, it only prints how, unless given `--yes`. Pass options after
`sh -s --`, such as `--version 0.0.10` or `--dir DIR`; see `--help`.

Or download the archive for your system from the
[latest release](https://github.com/thebrandonlucas/kai/releases/latest),
check it against the release's `SHA256SUMS`, and put `kai` on `PATH`:

```sh
tar -xzf kai-0.0.10-x86_64-linux.tar.gz
install -Dm755 kai ~/.local/bin/kai
kai --version
```

The archive contains only the `kai` binary. Kai evaluates `Kaifile.roc` with
the Roc compiler named in [`.roc-version`](.roc-version): one on `PATH` or set
as `ROC=/path/to/roc`, or else one it gets with Nix from
[roc-overlay](https://github.com/roc-lang/roc-overlay). Without Nix, it
downloads the nightly, by the digests in [`.roc-downloads`](.roc-downloads),
into its cache. Roc downloads the platform the first time it checks a `Kaifile.roc`.

With Nix, you can also run or install the latest release from this
repository's flake:

```sh
nix run github:thebrandonlucas/kai -- --version
nix profile install github:thebrandonlucas/kai
```

