# Shells and tasks

`kai run wisdom` runs the `wisdom` task in its environment: `fortune` piped
into `cowsay`, neither of them installed on the machine itself.

`kai shell` enters the default shell, with the environment's tools on
`PATH`. Name a shell to enter another, or put a command after `--` to run just
that:

```sh
kai shell                              # the default shell
kai shell default -- cowsay hello      # one command in it
kai run wisdom -- extra arguments      # appended to the task's command
```

Tasks run their command exactly as written, without a shell. For pipes, use
`sh -c`, as `wisdom` does.

Inside a project, `kai --help` lists its shells, tasks, builds and workflows.
