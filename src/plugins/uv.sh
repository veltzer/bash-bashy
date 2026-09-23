# This is a plugin for uv

function _activate_uv() {
	local -n __var=$1
	local -n __error=$2
	if ! checkInPath "uv" __var __error; then return; fi
	if ! bashy_completion uv uv --generate-shell-completion bash
	then
		__var=1
		__error="problem in sourcing uv completion"
		return
	fi
	__var=0
}

# The pypi token lives in pass(1) only. It is fetched when "uv publish" runs and
# set for that process; every other uv invocation runs untouched.
function uv() {
	case "${1:-}" in
		publish)
			bashy_with_secret UV_PUBLISH_TOKEN "keys/pypi" uv "$@"
			;;
		*)
			command uv "$@"
			;;
	esac
}

function _install_uv() {
	# uv ships prebuilt binaries, but this installer builds it from source as a
	# rust executable. uv is not published on crates.io, so cargo pulls the
	# tagged source from github and compiles it - expect the build to take a
	# few minutes and to need a recent rust toolchain.
	if ! command -v cargo > /dev/null
	then
		echo "uv: cargo not found - install rust first" >&2
		return 1
	fi
	local release_json
	bashy_github_release "astral-sh/uv" release_json || return
	local latest_version
	# uv tags releases with the bare version number, so there is no v to strip
	latest_version=$(bashy_github_version "${release_json}" "")
	local folder
	folder=$(bashy_install_dir)
	local executable="${folder}/uv"
	local installed_version=""
	if [ -x "${executable}" ]
	then
		installed_version=$("${executable}" --version 2>/dev/null | awk '/^uv /{print $2; exit}')
	fi
	if bashy_install_check "uv" "${installed_version}" "${latest_version}"
	then
		return
	fi
	# cargo install cannot place binaries straight into a chosen folder: it
	# always writes to <root>/bin, plus bookkeeping next to it. Build into a
	# scratch root and copy just the binaries over.
	local root
	root=$(mktemp --directory)
	if ! cargo install --locked --git "https://github.com/astral-sh/uv" --tag "${latest_version}" --root "${root}" uv
	then
		rm -rf "${root}"
		echo "uv: cargo build failed" >&2
		return 1
	fi
	rm -f "${executable}" "${folder}/uvx"
	cp "${root}/bin/uv" "${folder}"
	# the crate also builds the uvx companion binary, carry it along when there
	if [ -x "${root}/bin/uvx" ]
	then
		cp "${root}/bin/uvx" "${folder}"
	fi
	rm -rf "${root}"
}

function _uninstall_uv() {
	bashy_uninstall_binary "uv"
	bashy_uninstall_binary "uvx"
}

# Undo the activation in the running shell, for bashy_deactivate.
function _deactivate_uv() {
	unset -f uv
	complete -r uv 2> /dev/null
}

register_interactive _activate_uv _deactivate_uv
register_install _install_uv
