# This is integration of codex, the OpenAI command line coding tool
# https://github.com/openai/codex
# The api key is read from pass(1) when codex runs, not at shell start, and is
# set for that process only. This also grants codex all permissions.
function codex() {
	bashy_with_secret OPENAI_API_KEY "keys/openai" codex --dangerously-bypass-approvals-and-sandbox "$@"
}

function _activate_ai_codex() {
	local -n __var=$1
	local -n __error=$2
	__var=0
}

function _install_codex() {
	bashy_install_args "$@" || return
	local release_json
	bashy_github_release "openai/codex" release_json || return
	# codex tags its releases "rust-v<version>"
	local latest_version
	latest_version=$(bashy_github_version "${release_json}" "rust-v")
	# codex needs its whole package next to the binary: codex-package.json,
	# codex-path/ and codex-resources/ sit beside bin/, and without them the TUI
	# refuses to start its app-server daemon ("this CLI has no complete local
	# package"). So the package is unpacked whole into its own folder and only a
	# symlink to bin/codex goes into the binaries folder.
	local package="${HOME}/install/codex"
	local folder
	folder=$(bashy_install_dir)
	local executable="${folder}/codex"
	local installed_version=""
	if [ -x "${executable}" ] && [ -f "${package}/codex-package.json" ] && [ -x "${package}/bin/codex-code-mode-host" ]
	then
		installed_version=$("${executable}" --version 2>/dev/null | awk '/^codex-cli/{print $2; exit}')
	fi
	if bashy_install_check "codex" "${installed_version}" "${latest_version}"
	then
		return
	fi
	# The bare "codex-x86_64-unknown-linux-musl.tar.gz" asset is not listed in the
	# published checksums, so fetch the "package" tarball that is.
	local download_file
	bashy_github_asset "${release_json}" "codex-package-x86_64-unknown-linux-musl\\.tar\\.gz$" download_file || return
	bashy_install_download "${download_file}"
	local tar
	bashy_download "${download_file}" tar || return
	local checksums
	bashy_github_asset "${release_json}" "codex-package_SHA256SUMS$" checksums || return
	bashy_verify_sha256 "${tar}" "${checksums}" || return
	# older installs left bare copies of these two in the binaries folder
	rm -rf "${package}" "${executable}" "${folder}/codex-code-mode-host"
	mkdir -p "${package}"
	bashy_install_extract "${tar}" "${package}" || return
	ln -sfn "${package}/bin/codex" "${executable}"
}

function _uninstall_codex() {
	bashy_uninstall_binary "codex"
	bashy_uninstall_binary "codex-code-mode-host"
	bashy_uninstall_directory "codex" "${HOME}/install/codex"
}

function _install_codex_npm() {
	bashy_install_args "$@" || return
	bashy_install_npm "codex" "@openai/codex@latest"
}

function _uninstall_codex_npm() {
	bashy_uninstall_npm "codex" "@openai/codex"
}

function _install_codex_brew() {
	bashy_install_args "$@" || return
	bashy_install_brew "codex" "codex"
}

function _uninstall_codex_brew() {
	bashy_uninstall_brew "codex" "codex"
}

# Undo the activation in the running shell, for bashy_deactivate.
function _deactivate_ai_codex() {
	unset -f codex
}

register_interactive _activate_ai_codex _deactivate_ai_codex
register_install _install_codex
