# Your first Kaifile

In an empty directory, `kai init` writes a starter `Kaifile.roc` (in the
Kaifile pane). It is an ordinary [Roc](https://roc-lang.org) program: a header that
names Kai's platform and its standard plugin, `std`, then a list of settings.

| Setting | What it does |
| --- | --- |
| `Name` | The project's name. |
| `Systems` | The machines it supports. |
| `Environment` | A named set of tools, here `cowsay` and `fortune`. |
| `Shell` | A shell with an environment's tools on `PATH`. |
| `Task` | A command that runs inside an environment. |

Tool names are the backend's own package names, so anything in
[nixpkgs](https://search.nixos.org/packages) works.

`kai check` compiles the file and checks the settings without building or
running anything. A typo in a setting is a compile error, caught here, not
halfway through a build.
