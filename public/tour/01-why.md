# Why Kai

You figured out your setup once: the right compiler, the right libraries, the
commands that build and test the project. Then a laptop dies, a teammate joins,
or a server needs rebuilding, and you figure it out again.

**Determinate systems** like [Nix](https://nixos.org) and
[Guix](https://guix.gnu.org) end that. Every tool comes from an exact, pinned
source, so the same file gives the same environment on any machine, today or in
five years.

They are also hard to learn. Kai is a friendly frontend for them, the way
[jujutsu](https://github.com/jj-vcs/jj) is for git:

- **One file**, `Kaifile.roc`, describes a project's environments, shells,
  tasks, builds and workflows.
- **A few commands**, `kai shell`, `kai run`, `kai build`, do the rest.
- **Nix underneath** (and Guix), so everything stays reproducible.

> What if, once you painstakingly figured out your setup, you never had to
> figure it out again?

This tour starts from nothing. Press <kbd>j</kbd> or <kbd>↓</kbd> to go on.
