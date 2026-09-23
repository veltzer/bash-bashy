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
	local release_json
	bashy_github_release "openai/codex" release_json || return
	# codex tags its releases "rust-v<version>"
	local latest_version
	latest_version=$(bashy_github_version "${release_json}" "rust-v")
	local folder
	folder=$(bashy_install_dir)
	local executable="${folder}/codex"
	# codex spawns codex-code-mode-host next to itself, so an install without it is
	# incomplete and gets redone even when the version matches
	local host="${folder}/codex-code-mode-host"
	local installed_version=""
	if [ -x "${executable}" ] && [ -x "${host}" ]
	then
		installed_version=$("${executable}" --version 2>/dev/null | awk '/^codex-cli/{print $2; exit}')
	fi
	if bashy_install_check "codex" "${installed_version}" "${latest_version}"
	then
		return
	fi
	# The bare "codex-x86_64-unknown-linux-musl.tar.gz" asset is the same binary but
	# is not listed in the published checksums, so fetch the "package" tarball that is
	# and take bin/codex and bin/codex-code-mode-host out of it.
	local download_file
	bashy_github_asset "${release_json}" "codex-package-x86_64-unknown-linux-musl\\.tar\\.gz$" download_file || return
	bashy_install_download "${download_file}"
	local tar
	bashy_download "${download_file}" tar || return
	local checksums
	bashy_github_asset "${release_json}" "codex-package_SHA256SUMS$" checksums || return
	bashy_verify_sha256 "${tar}" "${checksums}" || return
	rm -f "${executable}" "${host}"
	bashy_install_extract "${tar}" "${folder}" "bin/codex" "bin/codex-code-mode-host" --transform 's/^bin\///'
}

function _uninstall_codex() {
	bashy_uninstall_binary "codex"
	bashy_uninstall_binary "codex-code-mode-host"
}

function _install_codex_npm() {
	bashy_install_npm "codex" "@openai/codex@latest"
}

function _uninstall_codex_npm() {
	bashy_uninstall_npm "codex" "@openai/codex"
}

function _install_codex_brew() {
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
