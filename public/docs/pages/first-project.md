# Your first project

A project is configured by `Kaifile.roc`, an ordinary
[Roc](https://roc-lang.org/) app on Kai's plugin platform. Its `kaifile` is
made of plugins; Kai's standard plugin, std, takes a list of settings:

```roc
app [kaifile] {
	pf: platform "https://github.com/thebrandonlucas/kai/releases/download/v0.0.10/9jXNkEdEWZ3cyQqHMLyTenLr4Xj5nEJT48UwnU8AxPCp.tar.zst",
	std: "https://github.com/thebrandonlucas/kai/releases/download/v0.0.10/std-CJKhhQ3UzajxpUqUKcpv2cwHGJpXQ8qPRiHKL5prqK2y.tar.zst",
}

import std.Std

kaifile = Std.kaifile([
	Name("hello"),
	Systems(["x86_64-linux", "aarch64-linux"]),
	Environment("dev", [Tools(["cowsay", "python3"])]),
	Shell("default", [Use("dev")]),
	Task("hello", [Use("dev"), Run(["cowsay", "hello from kai"])]),
	Build(
		"greeting",
		[
			Use("dev"),
			Run(["sh", "-c", "cowsay built by kai > greeting.txt"]),
			Output("greeting.txt"),
		],
	),
	Workflow("ci", [RunTask("hello", []), BuildArtifact("greeting")]),
])
```

`kai --help` prints the header for the installed version: the platform and
std must come from the same release. Then:

```sh
kai check                         # compile and validate Kaifile.roc
kai update                        # pin package sources in .kai/lock.json
kai shell                         # enter the default shell
kai shell default -- cowsay hi    # or run one command in it
kai run hello                     # run a task
kai run hello -- again            # arguments after -- are appended
kai build greeting                # sandboxed build; prints the store path
kai workflow ci                   # run steps in order, stop at a failure
kai bundle-plugin plugins/deploy  # bundle a plugin package for hosting
```

Tool names are the backend's own package names: Nix attribute paths such as
`python3` or `rust-bin.stable."1.90.0".minimal` (quote a segment that is not a
plain identifier), or Guix specifications. Tasks run their argv exactly,
without a shell, so use `Run(["sh", "-c", "...", "sh"])` for pipes: `sh -c`
takes the argument after its script as `$0`, so the `"sh"` placeholder lets
arguments after `--` reach the script as `$1`, `$2`, ... and `"$@"`. In Roc
strings, multiline ones included, `${name}` is Roc interpolation, as is any
`${...}` such as `${name%.txt}`, so a script writes `$NAME`, or `\${NAME}`
where the shell needs braces. A backslash starts a Roc escape (`\\`, `\"`,
`\'`, `\$`, `\n`, `\r`, `\t`, `\u(41)`), so others, such as sed's `\(x\)` and
`\1`, are an "invalid escape sequence": write `\\(x\\)`, `\\1`, and `\\` for a
trailing line continuation. Every command has
help with examples, e.g. `kai run --help`; inside a project, help lists its
shells, tasks, builds and workflows.
`kai build -L` (`--print-build-logs`) shows the build's log as it runs, and
`kai build --out-link PATH` links PATH to the artifact and keeps it from
garbage collection.

