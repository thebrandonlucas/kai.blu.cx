# Tasks and builds

Shells and tasks run on your machine, in the project directory (or a task's
`Dir`), inside the environment's shell: they see your files, your network and
anything else you can reach, and what they write stays in the working tree.
`KAI_OPERATOR_SHELL` holds the `SHELL` kai was started from, since the
environment may replace `SHELL`.

A task gets the secrets it declares with `Secrets([...])` from a `.env` file
at the project root (`NAME=value` lines; `#` comments; no interpolation),
else from kai's environment, and never those only other tasks declare. Only
the names are in the Kaifile and plans; add `.env` to your `.gitignore`. A
name in its `OptionalEnvironmentVariables([...])` is optional, never read
from `.env`, and reaches it even when another task declares it secret.

Builds run sandboxed. A build gets a copy of the project (or of its
`BuildRoot`, from which it then runs), leaving out what its `.gitignore`
files ignore (`Files([...])` narrows the copy to the given relative paths),
plus only the tools its environment's shell has, its declared sources
(`$KAI_INPUTS`) and the artifacts of the builds it needs
(`$KAI_ARTIFACTS`). It has no network, and only its `Output` is kept, in the
store. On Nix, its tools are its build inputs, so their setup hooks run as in
`kai shell`: `pkg-config` finds the environment's libraries, and the compiler
their headers and library paths. Symbolic links in the project and its
sources must resolve inside them, and those in its `Output` inside the output
or into the store; Kai refuses any other. A Nix build's sources that are Roc
package bundles, such as
`tarball+https://…/<hash>.tar.zst`, are in its Roc package cache, so Roc
resolves those package URLs offline. The sandbox has no `/usr/bin/env`, so
run scripts as `sh script` or through an interpreter's path rather than
relying on a `#!/usr/bin/env` line. An artifact that embeds paths to its
inputs, such as Rust panic locations in `$KAI_INPUTS/<name>`, keeps those
inputs alive in its closure; remap them, e.g. with Rust's
`--remap-path-prefix=$KAI_INPUTS/<name>=/<name>`, and check the closure with
`nix path-info -rS <path>`.

The sandbox has no `.git` either, so a build that stamps a version declares
`Revision`: it gets `KAI_REVISION`, the project's
`git describe --tags --always --dirty` (such as `v0.2.0-3-gabc1234`), and
`KAI_COMMIT_DATE`, the date of its last commit (`YYYY-MM-DD`), both empty
outside git or when git is not installed. Its inputs then change with every
commit, which is why it is opt-in.

On Nix and the direct backend, every shell, task and build also gets
`KAI_SYSTEM`, the system it runs on,
such as `x86_64-linux` or `aarch64-darwin`, and, when its environment has a
`RustToolchain` (Nix only), `KAI_RUST_TARGET`, that system's Rust target
triple, such as `x86_64-unknown-linux-gnu`, for paths like
`target/$KAI_RUST_TARGET/release`. A variable of the same name in an `Env`
replaces them.

A Rust build reads its crates from a `CargoVendor` in its inputs through the
cargo configuration in the vendored directory, which replaces crates.io and
each git dependency with it. Cargo then reads the crates under
`$KAI_INPUTS/crates`, so remapping that path keeps them out of the
artifact's closure, as [examples/cargo-vendor](https://github.com/thebrandonlucas/kai/tree/v0.0.11/examples/cargo-vendor) does:

```sh
export RUSTFLAGS="--remap-path-prefix=$KAI_INPUTS/crates=/crates"
cargo build --offline --locked --config "$KAI_INPUTS/crates/.cargo/config.toml"
```

Use a task for work that touches the project or the outside world, such as
running tests, formatting or deploying. Use a build for an artifact that should
depend only on what it declares, not on the machine it is built on.

