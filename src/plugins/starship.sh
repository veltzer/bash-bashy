# https://starship.rs/

function _activate_starship() {
	local -n __var=$1
	local -n __error=$2
	if ! checkInPath "starship" __var __error; then return; fi
	eval "$(starship init bash)"
	if ! bashy_completion starship starship completions bash
	then
		__var=$?
		__error="could not source startship completion"
		return
	fi
	__var=0
}

function _install_starship() {
	# install the release asset directly rather than piping the vendor install.sh
	# into a shell, which would run unverified code from the network
	local release_json
	bashy_github_release "starship/starship" release_json || return
	local latest_version
	latest_version=$(bashy_github_version "${release_json}")
	local folder
	folder=$(bashy_install_dir)
	local executable="${folder}/starship"
	local installed_version=""
	if [ -x "${executable}" ]
	then
		installed_version=$("${executable}" --version 2>/dev/null | awk '/^starship /{print $2; exit}')
	fi
	if bashy_install_check "starship" "${installed_version}" "${latest_version}"
	then
		return
	fi
	local download_file
	bashy_github_asset "${release_json}" "starship-x86_64-unknown-linux-gnu\\.tar\\.gz$" download_file || return
	bashy_install_download "${download_file}"
	local tar
	bashy_download "${download_file}" tar || return
	bashy_verify_sha256 "${tar}" "${download_file}.sha256" || return
	rm -f "${executable}"
	bashy_install_extract "${tar}" "${folder}" starship
}

function _uninstall_starship() {
	bashy_uninstall_binary "starship"
}

register_interactive _activate_starship
register_install _install_starship
