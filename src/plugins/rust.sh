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
#
# "cargo login" and "cargo logout" are refused: they only manage the credentials
# file. login ignores CARGO_REGISTRY_TOKEN, prompts for a token and writes it to
# disk, which is exactly the copy this setup avoids, and logout has nothing to
# remove.
function cargo() {
	case "${1:-}" in
		publish|owner|yank|release)
			bashy_with_secret CARGO_REGISTRY_TOKEN "keys/crates.io" cargo "$@"
			;;
		login|logout)
			echo "cargo: the crates.io token comes from pass(1) entry [keys/crates.io] for every registry command, there is nothing to ${1}" >&2
			return 1
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

function _install_rust() {
	# rustup is the upstream-recommended install and the one _activate_rust is
	# built around (CARGO_HOME points at ${HOME}/install/cargo, which rustup
	# populates); the apt variant is kept for setups that prefer distro packages
	_install_rust_rustup
}

function _install_rust_rustup() {
	export CARGO_HOME="${HOME}/install/cargo"
	export RUSTUP_HOME="${HOME}/.rustup"
	local release_json
	bashy_github_release "rust-lang/rust" release_json || return
	local latest_version
	# rust tags its releases as bare versions, there is no "v" prefix to strip
	latest_version=$(bashy_github_version "${release_json}" "")
	# rustc in CARGO_HOME/bin is a rustup proxy, it reports the stable toolchain
	# that RUSTUP_HOME holds
	local rustc="${CARGO_HOME}/bin/rustc"
	local installed_version=""
	if [ -x "${rustc}" ]
	then
		installed_version=$("${rustc}" --version 2>/dev/null | grep -oP '^rustc \K[0-9]+\.[0-9]+\.[0-9]+' | head -1)
	fi
	if bashy_install_check "rust" "${installed_version}" "${latest_version}"
	then
		_install_rust_cargo_tools
		return
	fi
	if [ -n "${installed_version}" ]
	then
		# rustup is already in place, so an upgrade is its job: it moves the stable
		# toolchain forward and keeps the cargo subcommands in CARGO_HOME/bin intact
		"${CARGO_HOME}/bin/rustup" update stable || return
		_install_rust_cargo_tools
		return
	fi
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
	_install_rust_cargo_tools
}

# rustup only manages the toolchain. The cargo subcommands the fleet's builds and
# release scripts run (cargo nextest, cargo release, cargo deny, mdbook) are separate
# crates that live in CARGO_HOME/bin; put in whichever is missing so a fresh install
# is complete rather than leaving "no such command" for the next build to find, and
# leave the ones already there alone, because cargo install builds from source.
function _install_rust_cargo_tools() {
	local tool
	local missing=()
	for tool in cargo-nextest cargo-release cargo-deny mdbook
	do
		if [ ! -x "${CARGO_HOME}/bin/${tool}" ]
		then
			missing+=("${tool}")
		fi
	done
	if [ "${#missing[@]}" -eq 0 ]
	then
		return
	fi
	"${CARGO_HOME}/bin/cargo" install --locked "${missing[@]}"
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
register_install _install_rust
