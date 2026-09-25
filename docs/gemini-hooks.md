# Gemini native guard hook

When `BeforeTool` invokes `gsd-worktree-guard`, the guard accepts Gemini's
`activate_skill` payload (`tool_input.name`, optional `tool_input.args`) and
`run_shell_command` payload (`tool_input.command`). It uses the payload `cwd`,
`tool_input.cwd`, or `tool_input.directory` when present; otherwise it uses
`GEMINI_PROJECT_DIR` or the hook process directory. A direct `gsd-flow-next`
shell call is checked as `gsd-flow`, with its phase and `--repo` location.

The shell adapter parses arguments without evaluating shell text. It checks
simple direct `gsd-*` executable calls and exits 2 for a compound, wrapped,
expanded, or unparseable command containing a GSD name. Arbitrary shell
programs cannot be fully analyzed by this hook. The launch commands and
`gsd-flow-next` retain their own shared guard checks.
This conservative rule also blocks an unrelated command that merely quotes or
prints a GSD name (for example, `echo gsd-flow-next`).
The reverse also holds: the hook sees only the command text, so a command
that does not contain a `gsd-` name is allowed — including an alias, wrapper
or renamed symlink of a GSD command (`ln -s …/gsd-flow-next pp; pp 5`). The
hook cannot resolve such names; the mandatory guard inside `gsd-start` and
`gsd-flow-next` still runs whatever name they are called by.

Gemini hook parsing needs Python 3.7 or newer. If it is unavailable, a Gemini
hook invocation exits 2 rather than silently reporting success. Other tools
that do not mention GSD are allowed.
