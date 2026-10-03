# This is a plugin for biome, the rust formatter and linter for javascript,
# typescript, json and css - https://biomejs.dev/

function _activate_biome() {
	local -n __var=$1
	local -n __error=$2
	# biome ships no shell completion, so being on the path is all there is
	if ! checkInPath "biome" __var __error; then return; fi
	__var=0
}

function _install_biome() {
	bashy_install_args "$@" || return
	# every release in the biome repo is a cli release, tagged
	# "@biomejs/biome@<version>", so the latest release endpoint is reliable
	local release_json
	bashy_github_release "biomejs/biome" release_json || return
	local latest_version
	latest_version=$(bashy_github_version "${release_json}" "@biomejs/biome@")
	local folder
	folder=$(bashy_install_dir)
	local executable="${folder}/biome"
	local installed_version=""
	if [ -x "${executable}" ]
	then
		# biome --version prints "Version: 2.5.15"
		installed_version=$("${executable}" --version 2>/dev/null | awk '/^Version: /{print $2; exit}')
	fi
	if bashy_install_check "biome" "${installed_version}" "${latest_version}"
	then
		return
	fi
	# the release ships both a glibc and a musl linux build as raw binaries, so
	# anchor on the end of the name to match exactly one asset
	local download_file
	bashy_github_asset "${release_json}" "/biome-linux-x64$" download_file || return
	# the project publishes no checksums for its release assets, so there is
	# nothing to hand bashy_verify_sha256 here
	bashy_install_binary "biome" "${download_file}" "${executable}"
}

function _uninstall_biome() {
	bashy_uninstall_binary "biome"
}

register_interactive _activate_biome
register_install _install_biome
