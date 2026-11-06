# direnv

To load a shell into your own shell whenever you enter the project, with
[direnv](https://direnv.net), add an `.envrc` and run `direnv allow`:

```sh
watch_file Kaifile.roc .kai/lock.json
direnv_load kai shell default -- direnv dump
```

direnv reloads it when `Kaifile.roc` or the lock changes. It needs Nix:
Guix's pure shell drops the `PATH` and variable `direnv dump` needs. Avoid
nix-direnv's `use flake` on `.kai/generated/nix`: each kai command regenerates
that flake with only what it runs, so after `kai run` or `kai build` it may
not have the shell.

direnv waits for the shell before showing your prompt, which takes a while
after `kai update` or a Kaifile change. To keep the prompt free meanwhile,
replace direnv's shell hook with
[direnv-instant](https://github.com/Mic92/direnv-instant)'s: it runs the same
`.envrc` in the background and loads the shell once it is ready.

