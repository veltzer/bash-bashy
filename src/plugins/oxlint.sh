# This is a plugin for oxlint, the rust javascript/typescript linter from the
# oxc project - https://oxc.rs/docs/guide/usage/linter.html

function _activate_oxlint() {
	local -n __var=$1
	local -n __error=$2
	# oxlint ships no shell completion, so being on the path is all there is
	if ! checkInPath "oxlint" __var __error; then return; fi
	__var=0
}

function _install_oxlint() {
	bashy_install_args "$@" || return
	# oxc is a monorepo that cuts a release per product (oxlint_v*, oxfmt_v*,
	# crates_v*, ...), so the "latest release" endpoint may answer with some
	# other product. Walk the releases list and take the newest oxlint one.
	local releases_json
	if ! releases_json=$(curl --fail --silent --location "https://api.github.com/repos/oxc-project/oxc/releases?per_page=30")
	then
		echo "oxlint: could not fetch the releases" >&2
		return 1
	fi
	local release_json
	release_json=$(echo "${releases_json}" | jq --raw-output '[.[] | select(.tag_name | startswith("oxlint_v"))][0] // empty')
	if [ -z "${release_json}" ]
	then
		echo "oxlint: no oxlint_v* release among the latest releases" >&2
		return 1
	fi
	local latest_version
	latest_version=$(bashy_github_version "${release_json}" "oxlint_v")
	local folder
	folder=$(bashy_install_dir)
	local executable="${folder}/oxlint"
	local installed_version=""
	if [ -x "${executable}" ]
	then
		# oxlint --version prints "Version: 1.86.0"
		installed_version=$("${executable}" --version 2>/dev/null | awk '/^Version: /{print $2; exit}')
	fi
	if bashy_install_check "oxlint" "${installed_version}" "${latest_version}"
	then
		return
	fi
	# the release ships both a gnu and a musl linux build, so anchor on gnu to
	# match exactly one asset
	local download_file
	bashy_github_asset "${release_json}" "oxlint-x86_64-unknown-linux-gnu\\.tar\\.gz$" download_file || return
	bashy_install_download "${download_file}"
	local tar
	bashy_download "${download_file}" tar || return
	# the project publishes no checksums for its release assets, so there is
	# nothing to hand bashy_verify_sha256 here
	rm -f "${executable}"
	# the tarball holds a single binary named after the target triple
	bashy_install_extract "${tar}" "${folder}" "oxlint-x86_64-unknown-linux-gnu" --transform 's/^oxlint-x86_64-unknown-linux-gnu$/oxlint/'
}

function _uninstall_oxlint() {
	bashy_uninstall_binary "oxlint"
}

register_interactive _activate_oxlint
register_install _install_oxlint
