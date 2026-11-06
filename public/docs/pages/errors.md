# Exit codes and errors

| Exit code | Meaning |
|---|---|
| 0 | Success. |
| 1 | A failure of Kai's that no other code covers. |
| 2 | A usage error, such as an unknown command, task or flag, or `kai` without a command when stdout is not a terminal. |
| 6 | A step needs confirmation; pass `--yes` to accept it. |

A failing shell, task or build's exit status becomes Kai's unchanged, so any
code can also come from it; with `--json`, its `error` event says
`child_exited`.

With `--json`, a failure ends with an `error` event: `message` says what went
wrong, `exit_code` is Kai's exit code, `hint`, when Kai knows the fix, is
usually a command to run (`kai update`), `suggestions`, after a mistyped
command, task, shell, build or workflow, lists the closest names (Kai never
runs them), and `error` is one of these codes:

| `error` | Meaning |
|---|---|
| `invalid_usage` | The command line is wrong. |
| `refused` | The Kaifile refused the request. |
| `no_kaifile` | There is no `Kaifile.roc`. |
| `not_a_kaifile` | The `-f` file is not a Kaifile. |
| `kaifile_exists` | `kai init` found a `Kaifile.roc`. |
| `kaifile_invalid` | `Kaifile.roc` did not compile. |
| `incompatible_protocol` | `Kaifile.roc`'s platform needs another Kai. |
| `no_compiler` | The pinned Roc compiler is not available. |
| `unsupported_host` | Kai does not run on this system. |
| `bundle_failed` | `kai bundle-plugin` failed. |
| `bad_response` | Kai could not read the Kaifile's answer. |
| `invalid_project` | The project's settings or `.kai` are invalid. |
| `unsafe` | Kai refused an unsafe path or plan. |
| `missing_source` | A local source or overlay does not exist. |
| `stale_lock` | A locked local source changed since `kai update`. |
| `lock_failed` | Locking the inputs failed. |
| `update_conflict` | Another `kai update` ran at the same time. |
| `confirmation_required` | A step needs confirmation (exit code 6). |
| `declined` | A confirmation was answered no. |
| `child_exited` | A shell, task or build failed. |
| `missing_programs` | Programs an environment `Expect`s are not on `PATH`; `programs` lists them. |
| `missing_secret` | A secret is not set. |
| `invalid_dotenv` | `.env` has an invalid line. |
| `no_backend` | No backend can serve the request. |
| `no_implementation` | No plugin implements the command. |
| `plan_failed` | A plan failed without a code of its own; [docs/plugin.md](#plugins) lists the codes plans fail with. |
| `failed` | Any other failure. |

