function _activate_lens() {
	local -n __var=$1
	local -n __error=$2
	if ! checkInPath "lens" __var __error; then return; fi
	__var=0
}

function _install_lens() {
	# instructions for installing lens are at
	# https://docs.k8slens.dev/getting-started/install-lens/#install-lens-desktop-from-the-appimage
	local folder
	folder=$(bashy_install_dir)
	local executable="${folder}/lens"
	local download_file="https://api.k8slens.dev/binaries/latest.x86_64.AppImage"
	# Lens has no version endpoint and the AppImage cannot report its own version,
	# so the origin's ETag stands in for one and is recorded in the marker file.
	local latest_version
	latest_version=$(curl --fail --silent --head --location "${download_file}" | awk 'BEGIN{IGNORECASE=1} /^(etag|last-modified):/{sub(/\r$/,""); print; exit}')
	local installed_version
	installed_version=$(bashy_install_marker_version "${folder}" "lens" "${executable}")
	if bashy_install_check "lens" "${installed_version}" "${latest_version}"
	then
		return
	fi
	rm -f "$(bashy_install_marker "${folder}" "lens")"
	bashy_install_binary "lens" "${download_file}" "${executable}" || return
	bashy_install_marker "${folder}" "lens" "${latest_version}" > /dev/null
}

function _uninstall_lens() {
	bashy_uninstall_binary "lens"
	rm -f "$(bashy_install_marker "$(bashy_install_dir)" "lens")"
}

register _activate_lens
