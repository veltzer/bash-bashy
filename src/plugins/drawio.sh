function _install_drawio() {
	local release_json
	bashy_github_release "jgraph/drawio-desktop" release_json || return
	local latest_version
	latest_version=$(bashy_github_version "${release_json}")
	local installed_version
	installed_version=$(dpkg-query -W -f='${Version}' drawio 2>/dev/null || true)
	if bashy_install_check "drawio" "${installed_version}" "${latest_version}"
	then
		return
	fi
	local download_file
	bashy_github_asset "${release_json}" "amd64\\.deb$" download_file || return
	bashy_install_deb "drawio" "${download_file}"
}

function _uninstall_drawio() {
	bashy_uninstall_apt "drawio" "drawio"
}

function _activate_drawio() {
  local -n __var=$1
  local -n __error=$2
  __var=0
}

register_interactive _activate_drawio
