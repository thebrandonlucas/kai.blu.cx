# Options

- `-f`, `--file PATH`: use another configuration file. Its directory is the
  project root. Without it, kai uses the nearest `Kaifile.roc`: in the
  current directory or the first above it, up to the git repository's root,
  and says which when it is not in the current directory.
- `--json`: print Kai's own messages as JSON Lines, one object per line. Each
  has `type` and `message`, plus fields for its type (e.g. `backend`,
  `step_started`, `artifact`, or `error`, described in
  [Exit codes and errors](#errors)). Results, such as
  `describe`, `check`, `update` or a build's `artifact`, go to stdout, and
  progress and errors to stderr. Output from shells and tasks passes through
  unchanged; when a command runs one, stdout is only theirs, and its results
  go to stderr too, where Kai's events are the lines that start with `{`.
- `--no-color`, or a non-empty `NO_COLOR`: plain text.
- `--backend nix|guix`: see [Backends](#backends).
- `ROC`: the Roc compiler that evaluates `Kaifile.roc` (default: `roc`). It
  must be the pinned version; Kai says which one otherwise.

