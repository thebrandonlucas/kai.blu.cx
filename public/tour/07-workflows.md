# Workflows

A `Workflow` runs tasks and builds in order and stops at the first step that
fails, with that step's exit code. It is the same on your machine and in CI:

```roc
Workflow("ci", [RunTask("hello", []), BuildArtifact("greeting")]),
```

`kai workflow ci` runs `hello`, then builds `greeting`. Because both steps get
their tools from the pinned environment, CI no longer needs its own install
steps, only Nix and `kai`.
