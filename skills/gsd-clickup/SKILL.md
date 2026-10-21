---
name: gsd-clickup
description: "Read and write ClickUp tickets from the shell with gsd-clickup: read a task, comment, set status, create a task, edit its name/description/assignees/priority, find tasks, list workspace lists and members, or make any other ClickUp API call. Use whenever the user asks to look at, update, create or search ClickUp tasks/tickets, including when a ClickUp connector is missing, failing or out of quota."
---

# gsd-clickup — ClickUp tickets from the shell

One command for every ClickUp read and write, with the user's own API token.
It calls only `api.clickup.com` and has no daily quota (the REST API allows
about 100 calls a minute per token). Prefer it over a ClickUp chat connector.

Always call `gsd-clickup …`, never `gsd-tracker …` for ClickUp: `gsd-tracker`
follows the repo's `tracker =`, and with `tracker = none` its writes do
nothing yet still succeed.

## Login

`gsd-clickup check` → `✔ ClickUp token OK` (with `(profile <name>)` when the
repo sets `tracker_profile`, i.e. its own ClickUp user). On a token error,
tell the user to fix the token file it names; never ask them to paste a token
into the chat.

## Commands

`<id>` may be the bare id, `tk-<id>`, or the task URL.

| Want | Command |
|---|---|
| read a task (description + comments) | `gsd-clickup snapshot <id>` |
| comment | `gsd-clickup comment <id> "<text>"` |
| set status | `gsd-clickup status <id> "<status>"` |
| find tasks | `gsd-clickup tasks [--list <id>] [--status <s>] [--assign me] [--match <text>] [--closed]` |
| list ids (spaces, folders, lists) | `gsd-clickup lists` |
| member ids | `gsd-clickup members` |
| create | `gsd-clickup create <list-id> "<name>" [--desc <md>\|-] [--assign <who>] [--priority 1-4] [--tag <t>] [--parent <id>]` |
| edit | `gsd-clickup update <id> [--name …] [--desc <md>\|-] [--assign <who>] [--unassign <who>] [--status …] [--priority 1-4]` |
| anything else | `gsd-clickup api <GET\|POST\|PUT\|DELETE> </path> ['<json>']` (API v2 paths, e.g. `/task/<id>/tag/<tag>`) |

- `<who>` = `me`, a user id, an email or a username.
- Priority: 1 urgent, 2 high, 3 normal, 4 low.
- A long description: pipe it in with `--desc -`.
- `--match` filters task names over up to 1,000 tasks; narrow with `--list` first.
- `tasks` prints `<id>  [<status>]  <name> · <list>`; a `• more tasks` line means another `--page`.

## Rules

- Writes (create, update, status, comment, api POST/PUT/DELETE) change the
  team's real tracker: do only what the user asked, and report the id or URL
  you touched.
- `gsd-clickup --help` has the full option list.
