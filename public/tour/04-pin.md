# Pin everything

`kai update` pins every package source the Kaifile uses in
`.kai/lock.json`. From then on, every shell and task gets exactly the same
tools, on every machine, until you run `kai update` again.

Commit the lock file next to the Kaifile. Together they are the whole setup:
clone the repository anywhere and you get the same environment.

Kai updates every backend installed on the machine that fits the project.
Here that is Nix and Guix, so the same Kaifile works with either.

To update only some inputs, name them: `kai update default`.
