# this is a plugin for buck2

function _install_buck2() {
	# buck2 has no versioned releases: a rolling "latest" tag is moved to a new commit
	# every night and the assets under it are overwritten. The tag's published_at
	# never changes and the assets' updated_at is the upload time, which is the day
	# after the commit date that "buck2 --version" prints ("buck2 <date>-<sha>"), so
	# neither can be compared with the binary. The commit sha can: the tag points at
	# the exact commit the binary was built from, so the version on both sides is the
	# full sha.
	local repo="facebook/buck2"
	local asset="buck2-x86_64-unknown-linux-gnu.zst"
	local ref_json
	if ! ref_json=$(curl --fail --silent --location "https://api.github.com/repos/${repo}/git/ref/tags/latest")
	then
		echo "buck2: could not fetch the commit of the latest tag" >&2
		return 1
	fi
	local latest_version
	latest_version=$(echo "${ref_json}" | jq --raw-output '.object.sha')
	local folder
	folder=$(bashy_install_dir)
	local executable="${folder}/buck2"
	local installed_version=""
	if [ -x "${executable}" ]
	then
		installed_version=$("${executable}" --version 2>/dev/null | awk '/^buck2 /{print $2; exit}' | grep -oP '[0-9a-f]{40}$' || true)
	fi
	if bashy_install_check "buck2" "${installed_version}" "${latest_version}"
	then
		return
	fi
	# this is the one release that is not the project's "latest release", so it is
	# fetched by tag rather than with bashy_github_release
	local release_json
	if ! release_json=$(curl --fail --silent --location "https://api.github.com/repos/${repo}/releases/tags/latest")
	then
		echo "buck2: could not fetch the latest release" >&2
		return 1
	fi
	local download_file
	bashy_github_asset "${release_json}" "/${asset}$" download_file || return
	bashy_install_download "${download_file}"
	local zst
	bashy_download "${download_file}" zst || return
	# the asset is zstd compressed rather than an archive, so unpack it by hand, next
	# to the old binary so a failed decompression does not leave buck2 uninstalled
	local tmp="${executable}.part"
	if ! zstd --quiet --force --decompress "${zst}" -o "${tmp}"
	then
		rm -f "${tmp}"
		return 1
	fi
	# zstd copies the mtime of the cached download onto the output, stamp the install time instead
	touch "${tmp}"
	chmod +x "${tmp}"
	mv -f "${tmp}" "${executable}"
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

# Undo the activation in the running shell, for bashy_deactivate. The completion is dropped; the functions it defined stay, unused.
function _deactivate_buck2() {
	complete -r buck2 2> /dev/null
}

register_interactive _activate_buck2 _deactivate_buck2
register_install _install_buck2
