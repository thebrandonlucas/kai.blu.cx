# The .kai directory and the lock

`kai update` is the only command that resolves package sources. It writes
`.kai/lock.json`. `kai shell`, `run`, `build` and `workflow` only read it, and
ask you to run `kai update` when it is missing, when a source, input or an
environment's overlay order changed, or when a locked local source has
changed. An environment or tool using only locked sources needs no update.
Commit the lock; the rest of `.kai` is generated:

```gitignore
/.kai/*
!/.kai/lock.json
```

`KAI_DIR=<name>` moves the whole directory to another top-level name in the
project.

