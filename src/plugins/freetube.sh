# this is a plugin for freetube

function _install_freetube() {
	# FreeTube ships only prereleases, so the "latest release" endpoint is empty -
	# take the newest entry of the releases list instead.
	local releases_json
	if ! releases_json=$(curl --fail --silent --location "https://api.github.com/repos/FreeTubeApp/FreeTube/releases")
	then
		echo "freetube: could not fetch the releases" >&2
		return 1
	fi
	local release_json
	release_json=$(echo "${releases_json}" | jq --raw-output '.[0]')
	local download_file
	bashy_github_asset "${release_json}" "amd64\\.deb$" download_file || return
	local latest_version
	latest_version=$(echo "${download_file}" | grep -oP '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
	local installed_version
	installed_version=$(dpkg-query -W -f='${Version}' freetube 2>/dev/null || true)
	if bashy_install_check "freetube" "${installed_version}" "${latest_version}"
	then
		return
	fi
	bashy_install_deb "freetube" "${download_file}"
}

function _uninstall_freetube() {
	bashy_uninstall_apt "freetube" "freetube"
}

function _activate_freetube() {
	local -n __var=$1
	local -n __error=$2
	__var=0
}

register_interactive _activate_freetube
