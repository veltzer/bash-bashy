# This is integration of gh, the github command line tool
function _activate_gh() {
	local -n __var=$1
	local -n __error=$2
	if ! checkInPath "gh" __var __error; then return; fi
	bashy_completion gh gh completion -s bash
	__var=0
}

function _install_gh_apt() {
	bashy_install_apt "gh" "gh"
}

function _install_gh() {
	local release_json
	bashy_github_release "cli/cli" release_json || return
	local latest_version
	latest_version=$(bashy_github_version "${release_json}")
	local folder
	folder=$(bashy_install_dir)
	local executable="${folder}/gh"
	local installed_version=""
	if [ -x "${executable}" ]
	then
		installed_version=$("${executable}" --version 2>/dev/null | awk '/^gh version/{print $3; exit}')
	fi
	if bashy_install_check "gh" "${installed_version}" "${latest_version}"
	then
		return
	fi
	local download_file
	bashy_github_asset "${release_json}" "_linux_amd64\\.tar\\.gz$" download_file || return
	bashy_install_download "${download_file}"
	local tar
	bashy_download "${download_file}" tar || return
	local checksums
	bashy_github_asset "${release_json}" "_checksums\\.txt$" checksums || return
	bashy_verify_sha256 "${tar}" "${checksums}" || return
	rm -f "${executable}"
	# the binary sits under gh_<version>_linux_amd64/bin/, flatten it into folder
	bashy_install_extract "${tar}" "${folder}" --wildcards "*/bin/gh" --transform 's/.*\/bin\/gh/gh/g'
}

function _uninstall_gh() {
	bashy_uninstall_binary "gh"
}

register_interactive _activate_gh
