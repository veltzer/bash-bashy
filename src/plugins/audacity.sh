# this is a plugin for audacity. Mostly it installs audacity.

function _activate_audacity() {
	local -n __var=$1
	local -n __error=$2
	if ! checkInPath "audacity" __var __error; then return; fi
	__var=0
}

function _install_audacity() {
	local release_json
	bashy_github_release "audacity/audacity" release_json || return
	# audacity tags its releases "Audacity-<version>"
	local latest_version
	latest_version=$(bashy_github_version "${release_json}" "Audacity-")
	local folder
	folder=$(bashy_install_dir)
	local executable="${folder}/audacity"
	# the AppImage cannot report its own version ("audacity --version" just dumps
	# library paths), so the installer records what it put there in a marker file.
	local installed_version
	installed_version=$(bashy_install_marker_version "${folder}" "audacity" "${executable}")
	if bashy_install_check "audacity" "${installed_version}" "${latest_version}"
	then
		return
	fi
	# assets are named audacity-linux-<version>-<arch>.AppImage, with an aarch64
	# build alongside, so anchor on the architecture to match exactly one
	local download_file
	bashy_github_asset "${release_json}" "audacity-linux-[^/]*-x86_64\\.AppImage$" download_file || return
	local appimage
	bashy_download "${download_file}" appimage || return
	# audacity publishes a table of "name length hash" rather than a sha256sum file,
	# so pull out the digest for our asset and hand that over directly
	local sums expected
	if bashy_github_asset "${release_json}" "CHECKSUMS\\.txt$" sums 2>/dev/null
	then
		expected=$(curl --fail --location --silent "${sums}" | awk -v want="${download_file##*/}" '$1==want{print $3; exit}')
		if [ -n "${expected}" ]
		then
			bashy_verify_sha256 "${appimage}" "${expected}" || return
		fi
	fi
	rm -f "$(bashy_install_marker "${folder}" "audacity")"
	bashy_install_binary "audacity" "${download_file}" "${executable}" || return
	bashy_install_marker "${folder}" "audacity" "${latest_version}" > /dev/null
}

function _uninstall_audacity() {
	bashy_uninstall_binary "audacity"
	rm -f "$(bashy_install_marker "$(bashy_install_dir)" "audacity")"
}

register _activate_audacity
