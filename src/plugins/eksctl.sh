# this is a plugin for the eksctl aws tool
#
# References:
# - https://eksctl.io/introduction/#installation

function _activate_eksctl() {
	local -n __var=$1
	local -n __error=$2
	EKSCTL_BINARY="${BASHY_INSTALL_DIR}/eksctl"
	if ! checkExecutableFile "${EKSCTL_BINARY}" __var __error; then return; fi
	export EKSCTL_BINARY
	if ! bashy_completion eksctl eksctl completion bash
	then
		__var=$?
		__error="could not source eskctl bash completions"
		return
	fi
	__var=0
}

function _install_eksctl() {
	local release_json
	bashy_github_release "eksctl-io/eksctl" release_json || return
	local latest_version
	latest_version=$(bashy_github_version "${release_json}")
	local folder
	folder=$(bashy_install_dir)
	local executable="${folder}/eksctl"
	local installed_version=""
	if [ -x "${executable}" ]
	then
		installed_version=$("${executable}" version 2>/dev/null | head -1)
	fi
	if bashy_install_check "eksctl" "${installed_version}" "${latest_version}"
	then
		return
	fi
	local download_file
	bashy_github_asset "${release_json}" "eksctl_$(uname -s)_amd64\\.tar\\.gz$" download_file || return
	bashy_install_download "${download_file}"
	local tar
	bashy_download "${download_file}" tar || return
	local checksums
	bashy_github_asset "${release_json}" "eksctl_checksums\\.txt$" checksums || return
	bashy_verify_sha256 "${tar}" "${checksums}" || return
	rm -f "${executable}"
	bashy_install_extract "${tar}" "${folder}" eksctl
}

function _uninstall_eksctl() {
	bashy_uninstall_binary "eksctl"
}

register_interactive _activate_eksctl
