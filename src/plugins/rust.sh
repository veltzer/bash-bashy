function _activate_rust() {
	local -n __var=$1
	local -n __error=$2
	# ubuntu package installation
	# if ! checkInPath "cargo" __var __error; then return; fi
	# if ! checkInPath "rustc" __var __error; then return; fi
	# CARGO_HOME="${HOME}/.cargo"
	CARGO_HOME="${HOME}/install/cargo"
	CARGO_HOME_BIN="${CARGO_HOME}/bin"
	CARGO_ENV="${CARGO_HOME}/env"
	if ! checkDirectoryExists "${CARGO_HOME}" __var __error; then return; fi
	if ! checkDirectoryExists "${CARGO_HOME_BIN}" __var __error; then return; fi
	if ! checkReadableFile "${CARGO_ENV}" __var __error; then return; fi
	# sourcing the cargo env file is just adding ~/.cargo/bin to path at the head.
	# I'd rather do it with my functions.
	# shellcheck source=/dev/null
	source "${CARGO_ENV}"
	# _bashy_pathutils_add_head PATH "${CARGO_HOME_BIN}"
	export CARGO_HOME
	__var=0
}

# The crates.io token lives in pass(1) only; cargo reads it from
# CARGO_REGISTRY_TOKEN, so there is no ~/.cargo/credentials file. It is fetched
# only for the subcommands that talk to the registry as the owner, and only for
# that process. Every other cargo invocation runs untouched.
function cargo() {
	case "${1:-}" in
		publish|login|logout|owner|yank)
			bashy_with_secret CARGO_REGISTRY_TOKEN "keys/crates.io" cargo "$@"
			;;
		*)
			command cargo "$@"
			;;
	esac
}

function _remove_rust() {
	export CARGO_HOME="${HOME}/install/cargo"
	rm -rf "${CARGO_HOME}"
	sudo apt remove -y cargo rustc rust-src
}

function _install_rust_rustup() {
	export CARGO_HOME="${HOME}/install/cargo"
	export RUSTUP_HOME="${HOME}/.rustup"
	# sh.rustup.rs is a shim that downloads this same rustup-init and runs it. Fetch
	# the binary directly instead, because rust publishes a sha256 next to it, so it
	# can be checked before anything is executed.
	local base="https://static.rust-lang.org/rustup/dist/x86_64-unknown-linux-gnu"
	local init
	bashy_download "${base}/rustup-init" init || return 1
	bashy_verify_sha256 "${init}" "${base}/rustup-init.sha256" || return 1
	rm -rf "${CARGO_HOME}" "${RUSTUP_HOME}"
	# The cached copy is not executable and must not be chmod'ed in place. The copy
	# has to keep the name rustup-init: the binary looks at its own filename and
	# treats an unknown one as a request to proxy that tool.
	local runner_dir
	runner_dir=$(mktemp --directory)
	cp "${init}" "${runner_dir}/rustup-init"
	chmod +x "${runner_dir}/rustup-init"
	"${runner_dir}/rustup-init" -y --no-modify-path
	rm -rf "${runner_dir}"
}

function _install_rust_apt() {
	# these are the ubuntu packages for rust
	bashy_install_apt "rust" "cargo" "rustc" "rust-src"
}

function _uninstall_rust_apt() {
	bashy_uninstall_apt "rust" "cargo" "rustc" "rust-src"
}
function _uninstall_rust() {
	bashy_uninstall_directory "rust" "${HOME}/install/cargo" "${HOME}/.cargo" "${HOME}/.rustup"
}

# Undo the activation in the running shell, for bashy_deactivate.
function _deactivate_rust() {
	unset -f cargo
	_bashy_pathutils_remove PATH "${HOME}/install/cargo/bin"
	unset CARGO_HOME
}

register _activate_rust _deactivate_rust
