# This is a plugin for hugo

function _activate_hugo() {
	local -n __var=$1
	local -n __error=$2
	if ! checkInPath "hugo" __var __error; then return; fi
	if ! bashy_completion hugo hugo completion bash
	then
		__var=1
		__error="problem in sourcing hugo completion"
		return
	fi
	__var=0
}

function _install_hugo_apt() {
	bashy_install_apt "hugo" "hugo"
}

function _install_hugo() {
	# instructions for installing hugo are at https://gohugo.io/installation/linux/
	local release_json
	bashy_github_release "gohugoio/hugo" release_json || return
	local latest_version
	latest_version=$(bashy_github_version "${release_json}")
	local folder
	folder=$(bashy_install_dir)
	local executable="${folder}/hugo"
	local installed_version=""
	if [ -x "${executable}" ]
	then
		installed_version=$("${executable}" version 2>/dev/null | grep -oP 'v\K[0-9]+\.[0-9]+\.[0-9]+' | head -1)
	fi
	if bashy_install_check "hugo" "${installed_version}" "${latest_version}"
	then
		return
	fi
	# the release also ships a hugo_extended_withdeploy_... build, exclude it so this
	# matches exactly one asset rather than returning two urls
	local download_file
	bashy_github_asset "${release_json}" "hugo_extended_[0-9][^/]*_linux-amd64\\.tar\\.gz$" download_file || return
	bashy_install_download "${download_file}"
	local tar
	bashy_download "${download_file}" tar || return
	local checksums
	bashy_github_asset "${release_json}" "checksums\\.txt$" checksums || return
	bashy_verify_sha256 "${tar}" "${checksums}" || return
	rm -f "${executable}"
	bashy_install_extract "${tar}" "${folder}" hugo
}

function _uninstall_hugo() {
	bashy_uninstall_binary "hugo"
}

register_interactive _activate_hugo
