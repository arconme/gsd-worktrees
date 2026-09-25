# Standalone copy installation

Most users want a release install instead: `get.sh` / `gsd-update`, see
[releases.md](releases.md). It uses this same `--copy` mode, one folder per
release.

Installation requires Python 3.7+ (`python3` or `python`), checked before writing
destinations. Bash, Git and Perl are also required by the toolkit.

Run `./install.sh --copy` when the source checkout will be removed. The installer
copies `bin/`, `lib/`, `shims/`, `skills/`, and `install.sh` into a dedicated
runtime directory. Commands in `GSD_BIN_DIR` are symlinks to that copied runtime,
so they continue to work after the checkout is removed. The selected agent's
skills are also copied into its skill directory.

By default, `GSD_BIN_DIR` is `~/.local/bin` and the runtime directory is
`~/.local/share/gsd-worktrees`. Set `GSD_COPY_DIR` to choose another runtime
directory. Both paths are resolved to absolute paths before installation.

To update a standalone installation, run `install.sh --copy` from a newer
checkout with the same `GSD_BIN_DIR` and `GSD_COPY_DIR` values. The installer
preserves unrelated paths. If a package path has local changes, its old version
is moved to `.bak`, `.bak.1`, and so on before replacement. An unchanged
installation is idempotent. `gsd-sync` can still check project shims from a
standalone copy; its Git self-update step is skipped.

Use `--reuse-install-config` when updating to reuse providers and skill roots
recorded in `GSD_BIN_DIR/.gsd-install-manifest`; any `--agent` given with it is
added to the recorded ones. The manifest is parsed as data, never evaluated. Copy runtimes
record owned command names in `.gsd-owned-commands`; removed commands are moved
to backups and only their matching PATH symlinks are removed. Older runtimes
without an inventory cannot safely have obsolete files automatically retired.

The runtime and command directories must be separate from one another and from
the source checkout. The installer refuses overlapping destinations and runtime
root symlinks, including paths ending in a slash. Backups allow recovery.
