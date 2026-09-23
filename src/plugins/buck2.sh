# this is a plugin for buck2

function _install_buck2() {
	# buck2 ships from a rolling "latest" tag whose published_at never moves, so the
	# version is the date of the asset itself. "buck2 --version" prints "buck2 <date>-<hash>",
	# so both sides of the comparison end up as a plain YYYY-MM-DD date. This is the
	# one release that is not the project's "latest release", so it is fetched by tag.
	local asset="buck2-x86_64-unknown-linux-gnu.zst"
	local release_json
	if ! release_json=$(curl --fail --silent --location "https://api.github.com/repos/facebook/buck2/releases/tags/latest")
	then
		echo "buck2: could not fetch the latest release" >&2
		return 1
	fi
	local latest_version
	latest_version=$(echo "${release_json}" | jq --raw-output --arg asset "${asset}" '.assets[] | select(.name==$asset) | .updated_at' | cut -d'T' -f1)
	local folder
	folder=$(bashy_install_dir)
	local executable="${folder}/buck2"
	local installed_version=""
	if [ -x "${executable}" ]
	then
		installed_version=$("${executable}" --version 2>/dev/null | awk '/^buck2 /{print $2; exit}' | grep -oP '^[0-9]{4}-[0-9]{2}-[0-9]{2}')
	fi
	if bashy_install_check "buck2" "${installed_version}" "${latest_version}"
	then
		return
	fi
	local download_file
	bashy_github_asset "${release_json}" "/${asset}$" download_file || return
	bashy_install_download "${download_file}"
	local zst
	bashy_download "${download_file}" zst || return
	# the asset is zstd compressed rather than an archive, so unpack it by hand
	rm -f "${executable}"
	zstd --quiet --decompress "${zst}" -o "${executable}" || return
	chmod +x "${executable}"
}

function _uninstall_buck2() {
	bashy_uninstall_binary "buck2"
	# left over from the old published_at based version check
	rm -f "$(bashy_install_dir)/.buck2_published_at"
}

function _activate_buck2() {
	local -n __var=$1
	local -n __error=$2
	if ! checkInPath "buck2" __var __error; then return; fi
	bashy_completion buck2 buck2 completion bash
	__var=0
}

register_interactive _activate_buck2
