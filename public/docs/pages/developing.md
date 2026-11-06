# Developing Kai

```sh
git clone https://github.com/thebrandonlucas/kai.git
cd kai
kai shell default -- zig build ci    # or `kai shell`, then `zig build ci`
```

`zig build ci` includes the end-to-end tests, which run a built kai against
real Nix and, when it is installed, Guix, so it needs network access or a warm
Nix cache. `zig build e2e -- --nix` or `-- --guix` runs them on one backend,
and `zig build e2e-run` (or `-build`, `-workflow`, `-update`, ...) runs one;
`zig build guix-integration` runs every Guix test and fails without Guix. If
the shell is missing a dependency, please open an issue.

To try a checkout's kai on another project, build it and the platform host
it links Kaifiles with:

```sh
kai build kai-x64musl --out-link /tmp/kai-dev    # kai at /tmp/kai-dev/kai
kai shell default -- sh -c 'cd platform && zig build --release'
```

`kai-arm64musl` is the aarch64 build. The project's Kaifile.roc then names
the checkout's platform and std by relative path, as `examples/` do, such as
`pf: platform "../kai/platform/main.roc"` and
`std: "../kai/plugins/std/main.roc"`: Roc refuses an absolute platform path.

The code follows the pipeline:

- `platform`: Kai's plugin platform, the Roc platform `Kaifile.roc` builds
  on and the API every plugin uses: commands, backends, implementations,
  plans and the protocol kai speaks. It validates the Kaifile's plugins at
  compile time.
- `plugins/std`: the std plugin. It lowers its settings to its project model
  at compile time.
  - `plugins/std/model`: std's project model and its validation.
  - `plugins/std/backends/nix`, `plugins/std/backends/guix`: std's pure
    backends that plan files and argv from the model.
- `cli`: `kai` itself. It asks the compiled Kaifile for the command's
  candidate plans, chooses a backend, checks the plan and runs it.
- `devtool`: checks, integration tests and release tooling; see
  [devtool/README.md](https://github.com/thebrandonlucas/kai/blob/v0.0.11/devtool/README.md) and [RELEASE.md](https://github.com/thebrandonlucas/kai/blob/v0.0.11/docs/RELEASE.md).

