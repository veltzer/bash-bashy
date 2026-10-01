# this is a plugin for drawio (draw.io desktop)

function _install_drawio() {
	local release_json
	bashy_github_release "jgraph/drawio-desktop" release_json || return
	local latest_version
	latest_version=$(bashy_github_version "${release_json}")
	# the deb registers itself as "draw.io", not "drawio"
	local installed_version
	installed_version=$(dpkg-query -W -f='${Version}' draw.io 2>/dev/null || true)
	if bashy_install_check "drawio" "${installed_version}" "${latest_version}"
	then
		return
	fi
	local download_file
	bashy_github_asset "${release_json}" "drawio-amd64-.*\\.deb$" download_file || return
	local checksums
	bashy_github_asset "${release_json}" "Files-SHA256-Hashes\\.txt$" checksums || return
	local deb
	bashy_download "${download_file}" deb || return
	bashy_verify_sha256 "${deb}" "${checksums}" || return
	bashy_install_deb "drawio" "${download_file}"
}

function _uninstall_drawio() {
	bashy_uninstall_apt "drawio" "draw.io"
}

function _activate_drawio() {
	local -n __var=$1
	local -n __error=$2
	__var=0
}

register_interactive _activate_drawio
register_install _install_drawio
