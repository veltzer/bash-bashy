# This is a plugin for zola, the static site generator - https://www.getzola.org/

function _activate_zola() {
	local -n __var=$1
	local -n __error=$2
	if ! checkInPath "zola" __var __error; then return; fi
	if ! bashy_completion zola zola completion bash
	then
		__var=1
		__error="problem in sourcing zola completion"
		return
	fi
	__var=0
}

function _install_zola() {
	local release_json
	bashy_github_release "getzola/zola" release_json || return
	local latest_version
	latest_version=$(bashy_github_version "${release_json}")
	local folder
	folder=$(bashy_install_dir)
	local executable="${folder}/zola"
	local installed_version=""
	if [ -x "${executable}" ]
	then
		installed_version=$("${executable}" --version 2>/dev/null | awk '/^zola /{print $2; exit}')
	fi
	if bashy_install_check "zola" "${installed_version}" "${latest_version}"
	then
		return
	fi
	# the release ships both a gnu and a musl linux build, so anchor on gnu to
	# match exactly one asset
	local download_file
	bashy_github_asset "${release_json}" "zola-v[0-9][^/]*-x86_64-unknown-linux-gnu\\.tar\\.gz$" download_file || return
	bashy_install_download "${download_file}"
	local tar
	bashy_download "${download_file}" tar || return
	# the project publishes no checksums for its release assets, so there is
	# nothing to hand bashy_verify_sha256 here
	rm -f "${executable}"
	# the tarball also carries man pages under artifacts/ and the licenses,
	# extract just the binary
	bashy_install_extract "${tar}" "${folder}" zola
}

function _uninstall_zola() {
	bashy_uninstall_binary "zola"
}

# Undo the activation in the running shell, for bashy_deactivate. The completion is dropped; the functions it defined stay, unused.
function _deactivate_zola() {
	complete -r zola 2> /dev/null
}

register_interactive _activate_zola _deactivate_zola
register_install _install_zola
