function _activate_fzf_ubuntu() {
	local -n __var=$1
	local -n __error=$2
	# it seems that this collides with bash completion
	# stuff so this must be after the system_deafult script
	# which does bash completions.
	if ! checkInPath "fzf" __var __error; then return; fi
	FILE="${HOME}/.fzf.bash"
	if ! checkReadableFile "${FILE}" __var __error; then return; fi
	# shellcheck source=/dev/null
	if ! source "${FILE}"
	then
		local error=$?
		__var="${error}"
		__error="trouble with sourcing fzf config file [${error}]"
		return
	fi
	__var=0
}

function _activate_fzf() {
	local -n __var=$1
	local -n __error=$2
	FZF_PATH="${HOME}/install/fzf"
	local FZF_PATHBIN="${FZF_PATH}/bin"
	if ! checkDirectoryExists "${FZF_PATH}" __var __error; then return; fi
	if ! checkDirectoryExists "${FZF_PATHBIN}" __var __error; then return; fi
	_bashy_pathutils_add_head PATH "${FZF_PATHBIN}"
	export FZF_PATH
	__var=0
}

# fzf is installed from its repository rather than a release tarball because the
# install script in the clone is what lays down the key bindings and completion
# files that _activate_fzf sources; the binary itself the script downloads from the
# matching github release. The clone is taken at the release tag, so the version
# the binary reports is the one to compare against.
function _install_fzf() {
	# https://github.com/junegunn/fzf
	local folder="${HOME}/install/fzf"
	local release_json
	bashy_github_release "junegunn/fzf" release_json || return
	local latest_version
	latest_version=$(bashy_github_version "${release_json}")
	local executable="${folder}/bin/fzf"
	local installed_version=""
	if [ -x "${executable}" ]
	then
		# prints "0.65.0 (d1b3b4a)"
		installed_version=$("${executable}" --version 2>/dev/null | awk '{print $1; exit}')
	fi
	if bashy_install_check "fzf" "${installed_version}" "${latest_version}"
	then
		return
	fi
	bashy_install_git "fzf" "https://github.com/junegunn/fzf.git" "${folder}" \
		--depth 1 --single-branch --branch "v${latest_version}" || return
	"${folder}/install" --no-update-rc --key-bindings --completion > /dev/null
}

function _install_fzf_apt() {
	bashy_install_apt "fzf" "fzf"
}
function _uninstall_fzf() {
	bashy_uninstall_directory "fzf" "${HOME}/install/fzf" "${HOME}/.fzf"
}

register_interactive _activate_fzf
register_install _install_fzf
