# Why Roc

A Kaifile is a [Roc](https://roc-lang.org) program, not a configuration format.
That means:

- **Types.** A misspelled setting, a missing argument or a shell that uses an
  environment that doesn't exist is a compile error from `kai check`, with the
  line it is on.
- **A real language** when you need one: functions, lists and records to build
  settings instead of copying them.
- **Plugins.** Kai's settings come from plugins, `std` first, which are Roc
  packages. A plugin returns a plan; Kai carries it out. Plugins themselves
  never touch your machine.

`kai model` prints the validated configuration as data, and `--json` makes
Kai's own output easy for tools (and agents) to read.
