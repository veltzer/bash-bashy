# This is integration of akurtosis (kurtosis on the command line)
# https://docs.kurtosis.com/guides/adding-command-line-completion
function _activate_kurtosis() {
	local -n __var=$1
	local -n __error=$2
	if ! checkInPath "kurtosis" __var __error; then return; fi
	if ! bashy_completion kurtosis kurtosis completion bash
	then
		__var=$?
		__error="could not source kurtosis completion script"
	fi
	__var=0
}

function _install_kurtosis() {
	local release_json
	bashy_github_release "kurtosis-tech/kurtosis-cli-release-artifacts" release_json || return
	# kurtosis tags with the bare version number, there is no v to strip
	local latest_version
	latest_version=$(bashy_github_version "${release_json}" "")
	local folder
	folder=$(bashy_install_dir)
	local executable="${folder}/kurtosis"
	local installed_version=""
	if [ -x "${executable}" ]
	then
		installed_version=$("${executable}" version 2>/dev/null | grep -oP 'CLI Version:\s+\K[0-9]+\.[0-9]+\.[0-9]+' | head -1)
	fi
	if bashy_install_check "kurtosis" "${installed_version}" "${latest_version}"
	then
		return
	fi
	local download_file
	bashy_github_asset "${release_json}" "_linux_amd64\\.tar\\.gz$" download_file || return
	bashy_install_download "${download_file}"
	local tar
	bashy_download "${download_file}" tar || return
	local checksums
	bashy_github_asset "${release_json}" "checksums\\.txt$" checksums || return
	bashy_verify_sha256 "${tar}" "${checksums}" || return
	rm -f "${executable}"
	bashy_install_extract "${tar}" "${folder}" kurtosis
}

function _uninstall_kurtosis() {
	bashy_uninstall_binary "kurtosis"
}

register_interactive _activate_kurtosis
