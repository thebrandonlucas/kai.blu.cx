# Builds

A `Build` runs its commands in the **Nix sandbox**, from a fresh snapshot of
the project: no network, no stray files from your machine, only what the
environment provides. What it leaves in its `Output` becomes the artifact.

`kai build greeting` prints the artifact's **store path**. The same inputs give
the same path, so a build can be cached, shared and checked.

```sh
kai build greeting                   # build, print the store path
kai build greeting -L                # show the build's log as it runs
kai build greeting --out-link out    # link ./out to it, kept from GC
```

The Kaifile on the right is this tour's second project: one environment, a
task, a build and a workflow, which comes next.
