# This is a plugin for bun, the javascript runtime, bundler and package manager - https://bun.sh/
#
# The installer puts bun (and its bunx alias) into BASHY_INSTALL_DIR. Activation
# loads the bash completion and puts the folder "bun add --global" installs
# executables into (~/.bun/bin) on PATH, when that folder exists.

function _activate_bun() {
	local -n __var=$1
	local -n __error=$2
	if ! checkInPath "bun" __var __error; then return; fi
	# bun picks the completion script by $SHELL, which is not bash in every
	# environment a bash shell starts from, so name it explicitly
	if ! bashy_completion bun env SHELL=/bin/bash bun completions
	then
		__var=1
		__error="problem in sourcing bun completion"
		return
	fi
	if [[ -d "${HOME}/.bun/bin" ]]
	then
		_bashy_pathutils_add_tail PATH "${HOME}/.bun/bin"
	fi
	__var=0
}

function _install_bun() {
	bashy_install_via _install_bun_zip "$@"
}

function _uninstall_bun() {
	_uninstall_bun_zip
}

function _install_bun_zip() {
	bashy_install_args "$@" || return
	local release_json
	bashy_github_release "oven-sh/bun" release_json || return
	local latest_version
	# bun tags its releases "bun-v1.2.3"
	latest_version=$(bashy_github_version "${release_json}" "bun-v")
	local folder
	folder=$(bashy_install_dir)
	local executable="${folder}/bun"
	local installed_version=""
	if [[ -x "${executable}" ]]
	then
		installed_version=$({ "${executable}" --version 2>/dev/null || true; } | head -1)
	fi
	if bashy_install_check "bun" "${installed_version}" "${latest_version}"
	then
		return
	fi
	# the default build needs AVX2; the project ships a "baseline" build for
	# processors without it
	local asset="bun-linux-x64"
	if ! grep -q -w avx2 /proc/cpuinfo 2>/dev/null
	then
		asset="bun-linux-x64-baseline"
	fi
	local download_file
	bashy_github_asset "${release_json}" "/${asset}\\.zip$" download_file || return
	bashy_install_download "${download_file}"
	local zip
	bashy_download "${download_file}" zip || return
	local checksums
	bashy_github_asset "${release_json}" "/SHASUMS256\\.txt$" checksums || return
	bashy_verify_sha256 "${zip}" "${checksums}" || return
	# the zip holds the binary inside a folder named after the asset, so unpack
	# into a scratch folder and move just the binary into place
	local scratch
	scratch=$(mktemp --directory)
	if ! bashy_install_extract "${zip}" "${scratch}" "${asset}/bun"
	then
		rm -rf "${scratch}"
		return 1
	fi
	rm -f "${executable}" "${folder}/bunx"
	mv "${scratch}/${asset}/bun" "${executable}"
	rm -rf "${scratch}"
	# bun behaves as "bun x" when invoked as bunx, which is how upstream's own
	# installer provides bunx
	ln -s bun "${folder}/bunx"
}

function _uninstall_bun_zip() {
	bashy_uninstall_binary "bunx"
	bashy_uninstall_binary "bun"
}

# Undo the activation in the running shell, for bashy_deactivate. The completion is dropped; the functions it defined stay, unused.
function _deactivate_bun() {
	_bashy_pathutils_remove PATH "${HOME}/.bun/bin"
	complete -r bun 2> /dev/null
}

register_interactive _activate_bun _deactivate_bun
register_install _install_bun
