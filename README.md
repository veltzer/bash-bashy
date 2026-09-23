<!-- This file is generated. Do not edit it by hand: your changes will be
     lost on the next build. Edit the template it is rendered from, or the
     values that template reads, and build again. -->
# *bash-bashy* project by Mark Veltzer

description: bashy handles bash configuration for you

project website: https://veltzer.github.io/bash-bashy

author: Mark Veltzer

version: 0.1.1

![Code style: black](https://img.shields.io/badge/code%20style-black-000000.svg)

## github

![License](https://img.shields.io/github/license/veltzer/bash-bashy)

## build

![build](https://github.com/veltzer/bash-bashy/workflows/build/badge.svg)
Bashy is bash based system to enable you control of your bash with precision and elegance.
It is plugin based and allows for easy extension.

## Build status

![build](https://github.com/veltzer/bash-bashy/workflows/build/badge.svg)

## Demo

![Demo](resources/session.gif)

## Installing Bashy

Clone the repository and install the runtime part of it into `~/.bashy`:

```bash
git clone --depth 1 https://github.com/veltzer/bash-bashy.git
cd bash-bashy
./scripts/install_in_home.sh
```

Then edit `~/.bashrc` and add the following line as the last line:

```bash
source ~/.bashy/bashy.sh
```

In my own setup this is the only line I have in my `~/.bashrc`

The install script copies only what is needed at runtime, listed in `.includes`,
and it is incremental: it prints the files that changed and copies nothing else.
`--delete` prunes anything in `~/.bashy` that is no longer part of the install, so
a renamed or removed plugin does not linger. Run it again after every `git pull`.

Bashy finds its own core, plugins and `bashy.list` next to `bashy.sh`, so you can
also skip the install and source the checkout directly, which is handy while
developing a plugin:

```bash
source ~/git/bash-bashy/src/bashy.sh
```

To check whether the running `~/.bashy` still matches your checkout, pass the root
of the checkout (or nothing, to try the usual places):

```bash
bashy_check_deployment ~/git/bash-bashy
```

## Debugging Bashy

Just add this line before sourcing bashy:
```bash
set -o xtrace
```

To see all errors use:
```bash
bashy_errors
```

To get debug messages from the plugins as they load, create a `~/.bashy.config`
and set the log level in it. The levels are `BASHY_LOG_NONE` (0) up to
`BASHY_LOG_DEBUG` (5):

```bash
export BASHY_LOG_LEVEL=5
```

In a running shell `bashy_log_debug`, `bashy_log_info` and `bashy_log_none` switch
the level without editing anything.

## Working with Bashy

To check the status of the core of Bashy use:

```bash
bashy_status_core
```

To check the status of plugins of Bashy use:

```bash
bashy_status_plugins
```

The plugins to run, and the order to run them in, are listed in
`~/.bashy/bashy.list`. To add to that without editing the installed copy, create
`~/.bashy.list`: it is read after the installed list and a plugin named in both
takes the setting from the later file, so it can disable one that the installed
list enables:

```text
# this file supports hash comments
tmux
prompt
git
-careful_aliases
history
```

Bashy is set up once, when the shell starts, so after installing a new version or
editing the plugin list open a new shell, or replace the current one:

```bash
exec bash
```

A plugin that registered an installer can be installed from the shell, and one
that registered a deactivate function can be turned off in the running shell:

```bash
bashy_install uv
bashy_deactivate prompt_error
```

## Writing Bashy plugins

Bashy plugins may never fail a command (all commands need to return 0)

Bashy plugins need to set a variable passed by reference to either 0 or 1.

Here is the most basic plugin:

```bash
function _activate_hello_plugin() {
	local -n __var=$1
	# this means everything was ok
	__var=0
}
register _activate_hello_plugin
```

`register` takes an optional second function that undoes the activation, which
`bashy_deactivate <plugin>` runs on demand. Most shipped plugins have one; write
it whenever the activation has a clean inverse (an alias, a `PATH` entry, an
exported variable, a completion, a prompt hook) and leave it out when it does
not (`tmux`, `umask`). `register_interactive` is the same but
only registers in an interactive shell. `register_install` names the plugin's
installer, for `bashy_install <plugin>`:

```bash
register_interactive _activate_hello_plugin _deactivate_hello_plugin
register_install _install_hello
```

### Writing a prompt plugin

A prompt plugin registers a function that runs after every command you type, not
once at startup. Register it from your activation function:

```bash
function prompt_hello() {
	# runs on every prompt
	:
}

function _activate_prompt_hello() {
	local -n __var=$1
	local -n __error=$2
	_bashy_prompt_register prompt_hello
	__var=0
}
register_interactive _activate_prompt_hello
```

Because it runs that often, speed is the whole design constraint. A prompt function
that forks once costs a few milliseconds every single command, and there are nine
prompt plugins here, so it adds up quickly. Do not run a program if a shell builtin
or an already exported variable will do.

If you need to know whether the current directory is inside a git repository, call
`git_is_inside` rather than running `git` yourself, and `git_top_level` for the
root of the repository. Both remember the answer per directory, which took about
28 ms off every prompt when the plugins that ask were each forking their own
`git rev-parse`. Call `git_is_inside_flush` if a repository appears or disappears
under a directory you are already in.

Two helpers in `core/git.sh` cover the common shapes, so a plugin only says what
to do rather than how to notice when to do it. `git_prompt_repo_path` keeps a
folder of the repository on `PATH` while inside it, which is all `prompt_gems` and
`prompt_node` are. `git_prompt_repo_conf` watches for a file at the repository
root and calls an enter function on every prompt that finds it and an exit
function once on the way out, which is what `prompt_k8s`, `prompt_aws` and
`prompt_gcp` are built on:

```bash
function _prompt_hello_enter() { export HELLO_CONF="$1"; }
function _prompt_hello_exit() { unset HELLO_CONF; }
function prompt_hello() {
	git_prompt_repo_conf "prompt_hello" PROMPT_HELLO_CONF ".hello.conf" _prompt_hello_enter _prompt_hello_exit
}
```

Registration prepends, so prompt functions run in reverse registration order: a
plugin listed later in `bashy.list` gets to set `PS1` before an earlier one.

The exit status of the command the user just ran is in `BASHY_PROMPT_STATUS`. It
is captured once before any prompt function runs, so read that rather than `$?`,
which by then is the status of whatever prompt function ran before yours.

### Shell completions

Do not run a completion command directly at activation time. Every one of those is
a process spawn on every shell you open, and they added up to about a second here.
Use `bashy_completion` instead, which runs the command once and caches the result:

```bash
# instead of: source <(minikube completion bash)
bashy_completion minikube minikube completion bash
```

The first argument is the tool whose binary keys the cache, the rest is the command
to run. The cache lives under `${XDG_CACHE_HOME:-~/.cache}/bashy/completions` and is
keyed on the mtime of the tool, so upgrading the tool regenerates it by itself. A
cache hit costs no process at all: the check is the shell's own `-nt` test against
a stamp file. `bashy_completion_clean` drops the cache.

This is for completion output only. `zoxide init`, `starship init` and friends emit
shell setup that may embed per session state, so those keep running live.

### Secrets

Never read a secret at activation time. Every `pass show` is a gpg decryption of
about eight processes on every shell you open, and an exported key sits in the
environment of every process that shell ever starts. Wrap the tool in a function
of the same name instead, and fetch the key when it runs:

```bash
function hello() {
	bashy_with_secret HELLO_API_KEY "keys/hello" hello "$@"
}
```

`bashy_with_secret <variable> <pass path> <command...>` sets the variable for that
one command and nothing else. The command is started through `env`, which finds it
on `PATH`, so the wrapper does not call itself. For a tool that only needs the
secret for some subcommands, such as `cargo publish` or `uv publish`, switch on the
first argument and hand every other invocation to `command`.

### Writing an installer

Install functions are named `_install_<name>` and should never hardcode a version
number: always ask the project what its latest release is. The core modules provide
the pieces so that every plugin behaves and reports the same way.

```bash
function _install_hello() {
	local release_json
	bashy_github_release "someorg/hello" release_json || return
	local latest_version
	latest_version=$(bashy_github_version "${release_json}")
	local folder
	folder=$(bashy_install_dir)
	local executable="${folder}/hello"
	# an empty installed version means "not installed yet"
	local installed_version=""
	if [ -x "${executable}" ]
	then
		installed_version=$("${executable}" --version 2>/dev/null)
	fi
	# prints one of the three standard lines and says whether there is work to do
	if bashy_install_check "hello" "${installed_version}" "${latest_version}"
	then
		return
	fi
	local download_file
	bashy_github_asset "${release_json}" "_linux_amd64\\.tar\\.gz$" download_file || return
	bashy_install_download "${download_file}"
	local tar
	bashy_download "${download_file}" tar || return
	# verify whenever the project publishes checksums
	local checksums
	bashy_github_asset "${release_json}" "checksums\\.txt$" checksums || return
	bashy_verify_sha256 "${tar}" "${checksums}" || return
	rm -f "${executable}"
	bashy_install_extract "${tar}" "${folder}" hello
}

function _uninstall_hello() {
	bashy_uninstall_binary "hello"
}
```

The helpers involved:

| function | purpose |
| --- | --- |
| `bashy_install_check <name> <installed> <latest>` | print the standard install/upgrade/up to date line, return 0 when there is nothing to do |
| `bashy_install_download <url>` | report the artifact about to be fetched |
| `bashy_github_release <owner/repo> [out]` | fetch the latest release json |
| `bashy_github_version <json> [prefix]` | tag name with the prefix (default `v`) stripped |
| `bashy_github_asset <json> <regex> [out]` | the single asset url matching a regex, fails on an ambiguous match |
| `bashy_download <url> [out]` | download through the cache, revalidating against the origin |
| `bashy_verify_sha256 <file> <url or digest>` | check a download against a published sha256 |
| `bashy_install_extract <archive> <folder> [members...]` | unpack and stamp with the install time rather than the archive mtime |
| `bashy_install_dir` | the install directory, created if it is not there yet |
| `bashy_install_binary <name> <url> [path]` | fetch a single executable and install it, the cached copy is never chmod'ed in place |
| `bashy_install_deb <name> <url>` | fetch a `.deb` and install it, falling back to apt for its dependencies |
| `bashy_install_marker <folder> <name> [version]` | the file recording what is installed, for artifacts that cannot report their own version |
| `bashy_install_marker_version <folder> <name> <executable>` | read that file back, empty unless the executable is really there |
| `bashy_uninstall_binary <name> [path]` | remove a single binary from `~/install/binaries` |
| `bashy_uninstall_directory <name> <dir...>` | remove the directory tree(s) a plugin installed |

When the project ships through a package manager rather than as a release asset,
there is a helper per manager. These do no version arithmetic of their own: the
package manager already knows what is installed, and a second opinion here would
only be a slower, worse version of the one it has.

| function | purpose |
| --- | --- |
| `bashy_install_apt <name> <package...>` | install distribution packages |
| `bashy_uninstall_apt <name> <package...>` | purge them, reporting either way |
| `bashy_install_npm <name> <package...>` | install global npm packages |
| `bashy_uninstall_npm <name> <package...>` | remove them |
| `bashy_install_pip <name> <package...>` | install python packages |
| `bashy_uninstall_pip <name> <package...>` | remove them |
| `bashy_install_brew <name> <formula...>` | install homebrew formulae |
| `bashy_uninstall_brew <name> <formula...>` | remove them |
| `bashy_install_gh_extension <name> <owner/repo>` | install a `gh(1)` extension |
| `bashy_uninstall_gh_extension <name> <extension>` | remove one |
| `bashy_install_git <name> <url> <folder> [git args...]` | install by cloning, replacing any previous clone |

Downloads are cached under `${XDG_CACHE_HOME:-~/.cache}/bashy/downloads`, overridable
with `BASHY_DOWNLOAD_CACHE`. Cached files are revalidated with the origin, so a
rolling `latest` asset that keeps one filename forever is still refetched when it
changes upstream. Use `bashy_download_clean` to drop the cache.

Never pipe a remote script into a shell when the project ships a release asset that
can be downloaded and verified instead. When a vendor genuinely ships nothing but an
install script, download it first and run that file, so there is something on disk to
look at before it executes.

The `_uninstall_<name>` counterpart uses the matching helper, so that removing
something reports as consistently as installing it does: either `removing <path>`
for each thing it took away, or `no <name> detected` when there was nothing there.

## Core module load order

The modules in `core` are loaded in the order listed by `bashy_core_order` in
`bashy.sh`, not alphabetically. The list runs from the standalone modules to the
ones built on top of them, so a module may call into anything loaded before it and
does not have to source its own dependencies.

When adding a core module, put its name in that list at a point where everything it
uses is already loaded. A module left out of the list is still loaded, after all the
named ones.

## Profiling startup

Plugin activation is not timed unless you ask for it. To see where shell startup
time goes, put this in `~/.bashy.config`:

```bash
readonly BASHY_PROFILE=0
```

then open a shell and run `bashy_status_plugins`.

## Config files

You can activate various plgins via the `~/.bashy.config` file.

Here is an example:

```bash
readonly ENCFS_ENABLED=true
readonly ENCFS_FOLDER_CLEAR="${HOME}/insync.real"
readonly ENCFS_FOLDER_ENCRYPTED="${HOME}/insync/encrypted"
readonly ENCFS_PASS_PATH="passwords/encfs/insync"
readonly PROXY_ENABLED=false
```

This is a bash file and so you can overwrite values by using conditionals so:
```bash
if [ "$HOSTNAME" = "ion" ]
then
	readonly PROXY_ENABLED=true
	readonly PROXY_HTTP="http://proxy.corp.com:8080"
	readonly PROXY_HTTPS="http://proxy.corp.com:8080"
	readonly PROXY_NO="localhost,.corp.com"
fi
```

## Similar projects

* https://github.com/Bash-it/bash-it
* https://github.com/ohmyzsh/ohmyzsh
* https://github.com/ohmybash/oh-my-bash
* https://github.com/nojhan/liquidprompt
* https://github.com/daniruiz/dotfiles
* https://github.com/Gkiokan/.pimp-my-bash
* https://github.com/brujoand/sbp

## Articles

* https://www.freecodecamp.org/news/jazz-up-your-bash-terminal-a-step-by-step-guide-with-pictures-80267554cb22/
* https://medium.com/@mandymadethis/pimp-out-your-command-line-b317cf42e953
* https://www.maketecheasier.com/customise-bash-prompt-linux/
* https://www.computerworld.com/article/2833199/3-ways-to-pimp-your-bash-console.html

## contact me

[mark.veltzer@gmail.com](mailto:mark.veltzer@gmail.com)

Mark Veltzer, Copyright © 2017, 2018, 2019, 2020, 2021, 2022, 2023, 2024, 2025, 2026
