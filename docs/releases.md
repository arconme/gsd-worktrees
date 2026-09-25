# Releases, install and updates

## For users

Install the latest release (no git checkout needed):

```sh
curl -fsSL https://raw.githubusercontent.com/arconme/gsd-worktrees/main/get.sh | bash
curl -fsSL …/get.sh | bash -s -- --agent claude --agent codex    # choose agents
curl -fsSL …/get.sh | bash -s -- --version 0.2.0                  # a given release
```

Pinned (a given installer version, read before running):

```sh
curl -fsSL https://raw.githubusercontent.com/arconme/gsd-worktrees/v0.2.0/get.sh -o get.sh
less get.sh && bash get.sh --version 0.2.0
```

`get.sh`:

1. asks GitHub for the latest release (or takes `--version`);
2. downloads `gsd-worktrees-X.Y.Z.tar.gz` and `SHA256SUMS` from that release,
   and refuses to install when the checksum does not match;
3. runs the package's `install.sh --copy` into
   `~/.local/share/gsd-worktrees/releases/X.Y.Z/`, linking the commands in
   `~/.local/bin` and copying the skills into each agent's skill folder;
4. keeps the release you had before, removes older ones.

Env: `GSD_BIN_DIR`, `GSD_RELEASES_DIR`, the `GSD_<AGENT>_SKILL_DIR` variables,
and `GSD_UPDATE_REPO=owner/name` (a fork).

### Knowing about updates

Two versions are watched: gsd-worktrees (GitHub releases) and GSD itself
(`get-shit-done-cc` on npm, compared with `gsd-sdk -v`).

- `gsd-start`, `gsd-list` and `gsd-init` print one line on stderr per newer
  version — only when you run them in a terminal, so JSON, pipes and agent
  output stay clean.
- `gsd-doctor` always shows them (`↑` lines, also with `--quiet`, and an
  `updates` list in `--json`). They are not findings: the exit status is 0.
- The latest versions are cached for a day in
  `${XDG_CACHE_HOME:-~/.cache}/gsd-worktrees/` (`latest-version`,
  `latest-gsd-version`). Commands read the cache and refresh it in the
  background, so they never wait on the network.
- `GSD_NO_UPDATE_CHECK=1` turns all of this off.

### Updating

```sh
gsd-update --check            # installed vs latest, changes nothing
gsd-update                    # install the latest (keeps your agent choice)
gsd-update --version 0.2.0    # a given release — also how you go back
```

A git-checkout install (`./install.sh` from a clone) is updated with
`gsd-sync` (a `git pull`); `gsd-update` says so.

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
