# Backends

Kai picks a backend for each command. Nix is preferred when it is installed and
can serve the request. Guix is used when Nix is not installed, or when the
environment's tools come from a `GuixPackages` source. The direct backend,
which needs neither, comes last. `--backend nix`, `--backend guix` or
`--backend direct` forces one; Kai never falls back to another.

On Guix, `kai shell` and `kai run` run `guix time-machine -C CHANNELS --
shell -q --pure` with the environment's tools, at the Guix channel commits
Kai's lock pins. `kai build` runs `guix build -f` on a generated file whose
derivation runs the same sandboxed build runner as on Nix, and `kai workflow`
runs tasks and builds in order. `kai update` pins every installed backend that
fits, each in its own section of `.kai/lock.json` (`kai --backend guix update`
pins only Guix), and Guix commands refuse to run without a Guix pin. The first
Guix command at a new commit downloads, or builds, that Guix, which can take a
long time. Overlays, `Fetch` and build inputs (`Inputs([...])`) other than
`path:` sources need Nix. See
[examples/guix](https://github.com/thebrandonlucas/kai/tree/v0.0.11/examples/guix).

## Running without Nix or Guix

The direct backend runs shells and tasks from pinned downloads, for tools
built on Kai whose users cannot be assumed to have Nix. It serves an
environment whose tools are all `Fetch` or `FetchLocked` files, and needs only
`tar`, `chmod`, `sh` and `env` on the machine (and `xz` for a tar.xz):

```roc
kaifile = Std.kaifile([
	Name("site"),
	Systems(["x86_64-linux"]),
	FetchLocked(
		"zig",
		[
			{
				system: "x86_64-linux",
				url: "https://ziglang.org/download/0.16.0/zig-x86_64-linux-0.16.0.tar.xz",
				mirrors: [],
				program: Archive("zig-x86_64-linux-0.16.0/zig"),
			},
		],
	),
	Environment("dev", [Tools(["zig#zig"]), Expect(["git"])]),
	Task("test", [Use("dev"), Run(["zig", "build", "test"])]),
])
```

`kai update` downloads each file it has no pin for, on every declared system,
and records its SHA-256 and size in `.kai/lock.json`; `kai update zig` measures
zig's files again. `kai run test` then
checks that every `Expect` program is on `PATH`, makes the downloads ready, and
runs the task with them first on `PATH`.

Downloads go over HTTPS with no credentials into `kai/v1` in the cache
directory, named by SHA-256, and are hashed again before every use. An archive
is unpacked whole, after listing it: one with an absolute name, a `..` or a
link out of the tree is refused, and its files are made read-only. The store may be deleted at any time. See
[examples/direct](https://github.com/thebrandonlucas/kai/tree/v0.0.11/examples/direct).

A pinned download pins one file, not a dependency tree, so this suits static
binaries: a program needing the machine's shared libraries is only as
reproducible as the machine. A workflow of tasks runs; `kai build`, and a
workflow with a build, need Nix for its sandbox, as do tools from package sources, `Overlays`, `Alias`, `PackageEnv`,
`RustToolchain` and `Pure`.

One environment can mix tools from package sources with `FetchLocked`
downloads and `Expect`, such as a nightly compiler pinned by URL beside
`zip` from nixpkgs. Nix then serves its shells and tasks: it checks the
`Expect` programs, makes the downloads ready in the same store, and runs
inside the environment with them first on `PATH` (a shell with no command
starts the shell Kai was started from). `kai update` pins both. The direct
backend refuses such an environment, naming the tools that are not
downloads, and a build cannot use it, as its sandbox sees neither the
lock's direct pins nor the machine's programs. See
[examples/mixed](https://github.com/thebrandonlucas/kai/tree/v0.0.11/examples/mixed).

