# This is integration of bazel
function _activate_bazel() {
	local -n __var=$1
	local -n __error=$2
	if ! checkInPath "bazel" __var __error; then return; fi
	export BAZEL_OPTS="--host_jvm_args=-XX:+IgnoreUnrecognizedVMOptions"
	export BAZEL_JVM_FLAGS="-XX:+IgnoreUnrecognizedVMOptions"
	__var=0
}

function _install_bazel() {
	local release_json
	bashy_github_release "bazelbuild/bazel" release_json || return
	# bazel tags with the bare version number, there is no v to strip
	local latest_version
	latest_version=$(bashy_github_version "${release_json}" "")
	local folder
	folder=$(bashy_install_dir)
	local executable="${folder}/bazel"
	local installed_version=""
	if [ -x "${executable}" ]
	then
		installed_version=$("${executable}" --version 2>/dev/null | awk '/^bazel /{print $2; exit}')
	fi
	if bashy_install_check "bazel" "${installed_version}" "${latest_version}"
	then
		return
	fi
	# the release also ships a "nojdk" build, exclude it to match exactly one asset
	local download_file
	bashy_github_asset "${release_json}" "^(?!.*nojdk).*-linux-x86_64$" download_file || return
	local binary
	bashy_download "${download_file}" binary || return
	bashy_verify_sha256 "${binary}" "${download_file}.sha256" || return
	bashy_install_binary "bazel" "${download_file}" "${executable}"
}

function _uninstall_bazel() {
	bashy_uninstall_binary "bazel"
}

register_interactive _activate_bazel
