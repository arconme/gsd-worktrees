---
name: gsdw-tracker
description: "Read and write the repo's tickets (ClickUp tasks, or whatever tracker the repo uses) from the shell with gsd-tracker: read a ticket, comment, set status, create a ticket, edit its title/description/assignees/priority, or find tickets. Use whenever the user asks to look at, update, create or search tickets/tasks/issues, including when a tracker chat connector is missing, failing or out of quota."
---

# gsd-tracker — the repo's tickets from the shell

`gsd-tracker` is one command for every tracker. The repo's `.gsd.conf` picks
the tracker (`tracker = clickup | custom | none`) and the login
(`tracker_profile`), so the same calls work in every repo and act as the
right user. Use it instead of a tracker chat connector.

## First: which tracker?

Run `gsd-tracker which` once per repo, before any ticket work.

- `none` — no tracker is connected. **Stop and tell the user**; don't call
  `comment`/`status` (with `none` they do nothing yet still succeed). The fix
  is `tracker = clickup` (or `custom`) in `.gsd.conf`.
- anything else — go on. `gsd-tracker check` confirms the login. On a token
  error, tell the user to fix the token file it names; never ask them to paste
  a token into the chat.

## Shared commands (every tracker)

`<id>` may be the bare id, `tk-<id>`, `#<id>`, or the ticket URL.

| Want | Command |
|---|---|
| read a ticket (description + comments) | `gsd-tracker snapshot <id>` |
| comment | `gsd-tracker comment <id> "<text>"` |
| set status | `gsd-tracker status <id> "<status>"` |
| create | `gsd-tracker create <where> "<title>" [option…]` |
| edit | `gsd-tracker update <id> <option>…` |
| find | `gsd-tracker tasks [option…]` |

What `<where>` is and which options work depend on the tracker. A tracker
that can't do something says so (nonzero exit); report that, don't work
around it.

## ClickUp (`tracker = clickup`)

- `<where>` = a list id. Find it with `gsd-tracker lists`.
- create: `--desc <md>|-` (`-` = stdin), `--assign <who>`, `--status <s>`,
  `--priority 1-4` (1 urgent … 4 low), `--tag <t>`, `--parent <id>`.
- update: `--name`, `--desc`, `--assign`, `--unassign`, `--status`,
  `--priority`, `--parent`.
- tasks: `--list <id>`, `--status <s>`, `--assign <who>`, `--tag <t>`,
  `--closed`, `--match <text>` (name search over up to 1,000 tasks; narrow with
  `--list`), `--page <n>`. Prints `<id>  [<status>]  <name> · <list>`.
- `<who>` = `me`, a user id, an email or a username (`gsd-tracker members`).
- Anything else: `gsd-tracker api <GET|POST|PUT|DELETE> </path> ['<json>']`
  (ClickUp API v2 paths, e.g. `/task/<id>/tag/<tag>`).
- Full list: `gsd-clickup --help`. Outside a gsd-worktrees repo,
  `gsd-clickup <command>` is the same with the tracker fixed to ClickUp.

## Rules

- Writes (create, update, status, comment, api POST/PUT/DELETE) change the
  team's real tracker: do only what the user asked, and report the id or URL
  you touched.
- Don't run `start`/`finish` by hand: `gsd-start`/`gsd-finish` call them.
