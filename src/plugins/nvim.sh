function _activate_nvim() {
	local -n __var=$1
	local -n __error=$2
	if ! checkInPath "nvim" __var __error; then return; fi
	alias vi="nvim"
	alias vim="nvim"
	__var=0
}
function _activate_nvim_with_folder() {
	local -n __var=$1
	local -n __error=$2
	NVIM_PATH="${HOME}/install/nvim-linux-x86_64"
	local NVIM_PATHBIN="${NVIM_PATH}/bin"
	if ! checkDirectoryExists "${NVIM_PATH}" __var __error; then return; fi
	if ! checkDirectoryExists "${NVIM_PATHBIN}" __var __error; then return; fi
	_bashy_pathutils_add_head PATH "${NVIM_PATHBIN}"
	export NVIM_PATH
	# alias vi="nvim"
	# alias vim="nvim"
	__var=0
}

function _install_nvim() {
	bashy_install_args "$@" || return
	# https://github.com/neovim/neovim/blob/master/INSTALL.md
	local release_json
	bashy_github_release "neovim/neovim" release_json || return
	local latest_version
	latest_version=$(bashy_github_version "${release_json}")
	local folder
	folder=$(bashy_install_dir)
	local executable="${folder}/nvim"
	local installed_version=""
	if [ -x "${executable}" ]
	then
		installed_version=$("${executable}" --version 2>/dev/null | awk '/^NVIM v/{print substr($2,2); exit}')
	fi
	if bashy_install_check "nvim" "${installed_version}" "${latest_version}"
	then
		return
	fi
	local download_file
	bashy_github_asset "${release_json}" "nvim-linux-x86_64\\.appimage$" download_file || return
	# neovim publishes no checksums for its release assets, so there is nothing
	# to hand bashy_verify_sha256 here
	bashy_install_binary "nvim" "${download_file}" "${executable}"
}

function _install_nvim_latest_tar() {
	bashy_install_args "$@" || return
	local release_json
	bashy_github_release "neovim/neovim" release_json || return
	local latest_version
	latest_version=$(bashy_github_version "${release_json}")
	local folder="${HOME}/install/nvim-linux-x86_64"
	local executable="${folder}/bin/nvim"
	local installed_version=""
	if [ -x "${executable}" ]
	then
		installed_version=$("${executable}" --version 2>/dev/null | awk '/^NVIM v/{print substr($2,2); exit}')
	fi
	if bashy_install_check "nvim" "${installed_version}" "${latest_version}"
	then
		return
	fi
	local download_file
	bashy_github_asset "${release_json}" "nvim-linux-x86_64\\.tar\\.gz$" download_file || return
	bashy_install_download "${download_file}"
	local tar
	# neovim publishes no checksums for its release assets
	bashy_download "${download_file}" tar || return
	rm -rf "${folder}"
	bashy_install_extract "${tar}" "${HOME}/install"
}

# The nightly is a moving tag that is rebuilt every night, so the binary's own
# version string (a dev build with a commit hash) has nothing published to be
# compared against. The release does carry the time it was published, so that is
# recorded with bashy_install_marker and a nightly is only taken again when a
# newer one has been published since.
function _install_nvim_nightly_tar() {
	bashy_install_args "$@" || return
	local folder="${HOME}/install/nvim-linux-x86_64"
	local executable="${folder}/bin/nvim"
	local latest_version
	# a prerelease never shows up under releases/latest, so ask for the tag itself
	latest_version=$(curl --fail --silent --location \
		"https://api.github.com/repos/neovim/neovim-releases/releases/tags/nightly" \
		| jq --raw-output '.published_at')
	local installed_version
	installed_version=$(bashy_install_marker_version "${HOME}/install" "nvim-nightly" "${executable}")
	if bashy_install_check "nvim nightly" "${installed_version}" "${latest_version}"
	then
		return
	fi
	local download_file="https://github.com/neovim/neovim-releases/releases/download/nightly/nvim-linux-x86_64.tar.gz"
	bashy_install_download "${download_file}"
	local tar
	bashy_download "${download_file}" tar || return
	rm -rf "${folder}"
	bashy_install_extract "${tar}" "${HOME}/install" || return
	bashy_install_marker "${HOME}/install" "nvim-nightly" "${latest_version}" > /dev/null
}

function _install_nvim_apt() {
	bashy_install_args "$@" || return
	bashy_install_apt "nvim" "neovim"
}

function _install_nvim_lazy() {
	bashy_install_args "$@" || return
	# The starter repo (LazyVim/starter) is a template with no releases, so the
	# version that matters is the LazyVim plugin it pulls in. lazy.nvim clones
	# that into its own tree and checks out the release tag, so the installed
	# version is the tag sitting on HEAD there.
	local release
	bashy_github_release "LazyVim/LazyVim" release || return
	local latest_version
	latest_version=$(bashy_github_version "${release}")
	local lazyvim="${HOME}/.local/share/nvim/lazy/LazyVim"
	local installed_version=""
	if [ -d "${lazyvim}/.git" ]
	then
		# --points-at lists every tag on HEAD, which includes the moving
		# "stable" tag, so keep only the version one
		installed_version=$(git -C "${lazyvim}" tag --points-at HEAD 2>/dev/null | sed --quiet 's/^v//; /^[0-9]/p' | head -1)
	fi
	if bashy_install_check "nvim-lazy" "${installed_version}" "${latest_version}"
	then
		return
	fi
	bashy_install_git "nvim-lazy" "https://github.com/LazyVim/starter" "${HOME}/.config/nvim" --depth 1 --single-branch || return
	nvim --headless "+Lazy! sync" +qa
}

function _clean_nvim() {
	rm -rf "${HOME}/.cache/nvim" "${HOME}/.local/share/nvim" "${HOME}/.local/state/nvim"
}

function _config_clean_nvim() {
	rm -rf "${HOME}/.config/nvim"
}

function _uninstall_nvim() {
	bashy_uninstall_binary "nvim"
}

# Undo the activation in the running shell, for bashy_deactivate.
function _deactivate_nvim() {
	unalias vi vim 2> /dev/null
}

register_interactive _activate_nvim _deactivate_nvim
register_install _install_nvim
