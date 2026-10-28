# Releases, install and updates

## For users

Install the latest release (no git checkout needed):

```sh
curl -fsSL https://raw.githubusercontent.com/arconme/gsd-worktrees/main/install.sh | bash
curl -fsSL …/install.sh | bash -s -- --agent claude --agent codex    # choose agents
curl -fsSL …/install.sh | bash -s -- --version 0.2.0                  # a given release
```

Read it before running:

```sh
curl -fsSL https://raw.githubusercontent.com/arconme/gsd-worktrees/main/install.sh -o install.sh
less install.sh && bash install.sh
```

`./install.sh` in a git checkout does the same: it installs the release, not
the checkout's files. So repos on a machine where you work on the toolkit
still run a release.

`install.sh`:

1. asks GitHub for the latest release (or takes `--version`);
2. downloads `gsd-worktrees-X.Y.Z.tar.gz` and `SHA256SUMS` from that release,
   and refuses to install when the checksum does not match;
3. runs the package's `lib/install.sh` (an older release: its `install.sh --copy`) into
   `~/.local/share/gsd-worktrees/releases/X.Y.Z/`, linking the commands in
   `~/.local/bin` and copying the skills into each agent's skill folder;
4. keeps the release you had before, removes older ones.

`lib/install.sh` then installs GSD itself (gsd-core) for each chosen agent that
has none: `npx -y --package=@opengsd/gsd-core@latest -- gsd-core --<agent>
--global --profile=full` (`--config-dir` added when `CLAUDE_CONFIG_DIR` /
`CODEX_HOME` moves the agent's dir). It runs after our skills, which are
`gsdw-*`, so gsd-core's installer keeps them. It is skipped when the agent
already has gsd-core (`gsd-update` updates it), on an update
(`--reuse-install-config`, which `gsd-update` uses), and with `--no-core`. A failed or
impossible install (no `npx`) prints the command and never fails the
toolkit install.

Env: `GSD_BIN_DIR`, `GSD_RELEASES_DIR`, the `GSD_CLAUDE_SKILL_DIR` / `GSD_CODEX_SKILL_DIR` variables,
and `GSD_UPDATE_REPO=owner/name` (a fork).

### Knowing about updates

Two versions are watched: gsd-worktrees (GitHub releases) and GSD itself
(`@opengsd/gsd-core` on npm, compared with the installed gsd-core version;
the update command is `npx @opengsd/gsd-core@latest --claude --global`).

- `gsd-start`, `gsd-list` and `gsd-init` print one line on stderr per newer
  version — only when you run them in a terminal, so JSON, pipes and agent
  output stay clean.
- `gsd-doctor` always shows them (`↑` lines, also with `--quiet`, and an
  `updates` list in `--json`). They are not findings: the exit status is 0.
- The latest versions are cached for a day in
  `${XDG_CACHE_HOME:-~/.cache}/gsd-worktrees/` (`latest-version`,
  `latest-gsd-core-version`). Commands read the cache and refresh it in the
  background, so they never wait on the network.
- `GSD_NO_UPDATE_CHECK=1` turns all of this off.

### Updating

```sh
gsd-update --check            # installed vs latest, changes nothing
gsd-update                    # install the latest (keeps your agent choice), then gsd-core
gsd-update --version 0.2.0    # a given release — also how you go back
gsd-update --no-core          # leave gsd-core as it is
```

After the toolkit, `gsd-update` brings gsd-core to npm's latest for each
agent the install chose (`lib/core.sh`, the same `--profile=full` installer
run as a fresh install). An agent without gsd-core gets it; one on the latest
is left alone. Offline, or without `npx`, it prints the command to run. The
update notice and `gsd-doctor` name `gsd-update` for both.

A git checkout is not an install: pull it with `git pull`; `gsd-update` run
from it says so. Commands still linked into a checkout (how older versions of
`./install.sh` installed) move to a release with
`./install.sh --reuse-install-config`; `gsd-doctor` notes when you have them.

Projects keep only `.gsd.conf`, the frozen shims and instruction blocks. After
an update, `gsd-doctor` in a project tells you if its shims need
`gsd-init` again.

## For maintainers: cutting a release

1. Add a `## X.Y.Z` section at the top of `CHANGELOG.md` (it becomes the
   release notes) and commit it on `main`.
2. Run:

   ```sh
   tools/release.sh X.Y.Z --push
   ```

   It checks that `main` is clean and level with origin, writes `VERSION`,
   commits `release vX.Y.Z`, tags `vX.Y.Z`, and pushes both.
3. `.github/workflows/release.yml` runs the whole test suite (Ubuntu + macOS),
   checks the tag matches `VERSION`, builds the tarball with `git archive`,
   and publishes the GitHub release with the tarball and `SHA256SUMS`.
4. Within a day, every install sees the new version.

Versions are `X.Y.Z`: bump Z for fixes, Y for new features, X for changes that
need users to do something (say so in the changelog).
