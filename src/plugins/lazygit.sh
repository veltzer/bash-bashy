# this is a plugin for lazygit
# this doesn't really do anything besides provide a function to install lazygit, I really
# need to think about plugins like that.

function _install_lazygit() {
	local release_json
	bashy_github_release "jesseduffield/lazygit" release_json || return
	local latest_version
	latest_version=$(bashy_github_version "${release_json}")
	local folder
	folder=$(bashy_install_dir)
	local executable="${folder}/lazygit"
	local installed_version=""
	if [ -x "${executable}" ]
	then
		installed_version=$("${executable}" --version 2>/dev/null | grep -oP 'version=\K[0-9]+\.[0-9]+\.[0-9]+' | head -1)
	fi
	if bashy_install_check "lazygit" "${installed_version}" "${latest_version}"
	then
		return
	fi
	# upstream renamed these from _Linux_x86_64 to _linux_x86_64, match either
	local download_file
	bashy_github_asset "${release_json}" "_[Ll]inux_x86_64\\.tar\\.gz$" download_file || return
	bashy_install_download "${download_file}"
	local tar
	bashy_download "${download_file}" tar || return
	local checksums
	bashy_github_asset "${release_json}" "checksums\\.txt$" checksums || return
	bashy_verify_sha256 "${tar}" "${checksums}" || return
	rm -f "${executable}"
	bashy_install_extract "${tar}" "${folder}" lazygit
}

function _activate_lazygit() {
	local -n __var=$1
	local -n __error=$2
	__var=0
}

function _uninstall_lazygit() {
	bashy_uninstall_binary "lazygit"
}

register _activate_lazygit
register_install _install_lazygit
