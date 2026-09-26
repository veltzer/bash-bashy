# Working on bashy

## Never delete plugins

Do not delete a plugin from `src/plugins/` because it is unused, disabled in
`bashy.list`, or its upstream project looks dead. bashy is a collection meant for
other people's setups, not only this machine - a plugin that works but is not needed
here may be exactly what someone else needs.

Plugins are free at runtime anyway: the `check*` helpers in `src/core/check.sh`
(`checkInPath`, `checkExecutableFile`, ...) make an inapplicable plugin a silent
no-op.

To opt out of a plugin locally, comment its line out in `bashy.list`. Leave the file
in place. "Unused here" and "upstream is archived" are not reasons to prune -
`src/plugins/phantomjs.sh` is pinned to a 2018 release and still stays.

Fix and improve plugins. Treat the set as additive.

## Never hardcode a version

An installer must ask the project what its latest release is, never carry a version
literal. Version numbers embedded in a download url count too, and so do pinned
distro codenames in an asset name.

The exceptions are deliberate and carry a comment saying so: `_install_zoom_6` pins
a version because it exists to downgrade, and `src/plugins/phantomjs.sh` pins one
because the project was archived with no releases to query.

## Core module load order

`src/core/*.sh` is loaded in the order given by `bashy_core_order` in `bashy.sh`, not
alphabetically. The list runs from the standalone modules to the ones built on top
of them, so a module may call into anything listed before it.

Modules must not source each other. When adding a core module, put its name in that
list at a point where everything it uses is already loaded. A module missing from
the list is still loaded, after the named ones.

Tests source modules directly, so a test has to list the dependencies itself, in the
same order.

## Writing an installer

Use the core helpers rather than hand rolling. They keep every plugin reporting the
same way and put the fixes in one place. See the "writing an installer" section of
`README.md` for a worked example and the full table.

- `bashy_install_check <name> <installed> <latest>` - prints the standard
  install/upgrade/up to date line, returns 0 when there is nothing to do
- `bashy_github_release` / `bashy_github_version` / `bashy_github_asset` - the
  latest release json, its version, and the one asset matching a regex
- `bashy_download <url> [out]` - download through the revalidating cache
- `bashy_verify_sha256 <file> <url or digest>` - check against a published sha256,
  whenever the project publishes one
- `bashy_install_extract <archive> <folder> [members...]` - unpack and stamp with
  the install time, because tar and unzip both restore the archive's own mtime
- `bashy_uninstall_binary` / `bashy_uninstall_directory` - for the `_uninstall_*`
  counterpart

Never pipe a remote script into a shell when the project ships a release asset that
can be downloaded and verified instead.

## Before saying it is done

Run `rsconstruct build`. It renders the templates, runs shellcheck over every shell
file and then `scripts/test_all.sh`, and lints the workflow (actionlint), the
markdown (rumdl) and the lua configs (luacheck).

Do not claim an item is complete without checking the code. Grep for what the claim
asserts rather than trusting a summary written earlier in the session.

## README.md is generated

Do not edit `README.md`. It is built by `rsconstruct build` from
`tera.templates/README.md.tera`, which includes `tera.snippets/main.md.tera`. The
prose sections all live in the snippet, and editing the generated file means the
change is silently lost at the next build. That has already happened once.

Tera treats `{{ ... }}` and `{% ... %}` as syntax, so a literal double brace in an
example has to sit inside a `{% raw %}` block. Plain shell `${HOME}` needs no
escaping. After editing the snippet run `rsconstruct build` and check `README.md`.

## Generated files

`rsconstruct build` regenerates `README.md`, `.github/dependabot.yml` and
`src/core/version.sh` from `tera.templates/`. These outputs are tracked in git, so
fix the template, never the output. The version in `config/version.lua` is bumped
by hand; nothing bumps it as a build side effect anymore.

The configs in `config/` are lua and templates read them with
`load_lua(path="...")` or `version_str(path="...")`; both add the file as a
content-tracked input, so the output is rebuilt when the config changes
(`rsconstruct functions list` shows what each function tracks).

`LICENSE` and `.github/workflows/build.yml` are not generated. Both are
fleet-wide files kept byte-identical by `rsmultigit check-same`, as are
`tera.templates/README.md.tera` and `tera.templates/.github/dependabot.yml.tera`,
so a change to any of them is a fleet change, not a change to this repo.
