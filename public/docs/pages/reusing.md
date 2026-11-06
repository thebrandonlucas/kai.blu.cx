# Reusing configuration

Reuse is ordinary Roc: a module returns settings and `Kaifile.roc` imports it.
From [examples/modules](https://github.com/thebrandonlucas/kai/tree/v0.0.11/examples/modules):

```roc
# CowTasks.roc
import std.Config
import std.EnvName

CowTasks :: [].{
	settings : EnvName -> List(Config.Setting)
	settings = |environment| [
		Task("moo", [Use(environment), Run(["cowsay", "moo"])]),
		Task("say", [Use(environment), Run(["cowsay"])]),
	]
}
```

```roc
# Kaifile.roc, after the app header
import CowTasks
import std.Std

kaifile = Std.kaifile(
	[
		Name("modules"),
		Environment("cow", [Tools(["cowsay"])]),
		Shell("default", [Use("cow")]),
	].concat(CowTasks.settings("cow")),
)
```

A module can only add settings. New commands, and replacements for one
command on one backend, come from plugins: Roc packages next to std in
`Kaifile.new([...])`. See [docs/plugin.md](#plugins) and
[examples/plugins/deploy](https://github.com/thebrandonlucas/kai/tree/v0.0.11/examples/plugins/deploy), which adds `kai deploy`.

