# this is a plugin for zoom

function _install_zoom() {
	local download_file="https://zoom.us/client/latest/zoom_amd64.deb"
	# zoom publishes no version endpoint, but the download redirects to a versioned
	# cdn path, so the effective url names the version on offer
	local effective_url
	effective_url=$(curl --fail --silent --head --location --output /dev/null --write-out '%{url_effective}' "${download_file}")
	local latest_version
	latest_version=$(echo "${effective_url}" | grep -oP '/prod/\K[^/]+')
	local installed_version
	installed_version=$(dpkg-query -W -f='${Version}' zoom 2>/dev/null || true)
	if bashy_install_check "zoom" "${installed_version}" "${latest_version}"
	then
		return
	fi
	bashy_install_deb "zoom" "${download_file}"
}

# This pins a version on purpose: it exists to downgrade from the 7.x line back to
# the last 6.x build, so it must not ask the project what the latest release is.
function _install_zoom_6() {
	local latest_version="6.4.6.1370"
	local installed_version
	installed_version=$(dpkg-query -W -f='${Version}' zoom 2>/dev/null || true)
	if bashy_install_check "zoom" "${installed_version}" "${latest_version}"
	then
		return
	fi
	bashy_install_deb "zoom" "https://cdn.zoom.us/prod/${latest_version}/zoom_amd64.deb"
}

function _uninstall_zoom() {
	bashy_uninstall_apt "zoom" "zoom"
}

function _activate_zoom() {
	local -n __var=$1
	local -n __error=$2
	__var=0
}

register_interactive _activate_zoom
