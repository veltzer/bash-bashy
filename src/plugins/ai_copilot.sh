function _activate_ai_copilot() {
	local -n __var=$1
	local -n __error=$2
	# running via gh(1)
	# alias copilot="gh copilot"
	# without permission checking via gh(1)
	#alias copilot="gh copilot --allow-all-tools"
	# without permission checking via npm
	alias copilot="copilot --allow-all-tools"
	__var=0
}

# Install the latest GitHub Copilot CLI, the standalone "copilot" agent.
# https://github.com/github/copilot-cli
# Every release ships a single binary tarball per platform plus a SHA256SUMS.txt,
# which is exactly what the vendor script (see _install_copilot_script) downloads,
# so this does the same thing directly and verifies it.
function _install_copilot() {
	local arch
	case "$(uname -m)" in
		x86_64|amd64) arch="x64" ;;
		arm64|aarch64) arch="arm64" ;;
		*)
			echo "copilot: unsupported architecture [$(uname -m)]" >&2
			return 1
			;;
	esac
	local release_json
	bashy_github_release "github/copilot-cli" release_json || return
	local latest_version
	latest_version=$(bashy_github_version "${release_json}")
	local executable
	executable="$(bashy_install_dir)/copilot"
	local installed_version=""
	if [ -x "${executable}" ]
	then
		# prints "GitHub Copilot CLI 1.0.88."
		installed_version=$("${executable}" --version 2>/dev/null | awk '/^GitHub Copilot CLI/{sub(/\.$/, "", $4); print $4; exit}')
	fi
	if bashy_install_check "copilot" "${installed_version}" "${latest_version}"
	then
		return
	fi
	local download_file
	bashy_github_asset "${release_json}" "/copilot-linux-${arch}\\.tar\\.gz$" download_file || return
	bashy_install_download "${download_file}"
	local tar
	bashy_download "${download_file}" tar || return
	local checksums
	bashy_github_asset "${release_json}" "/SHA256SUMS\\.txt$" checksums || return
	bashy_verify_sha256 "${tar}" "${checksums}" || return
	rm -f "${executable}"
	bashy_install_extract "${tar}" "$(bashy_install_dir)" "copilot"
}

function _uninstall_copilot() {
	bashy_uninstall_binary "copilot"
}

# The vendor install script, which installs into ~/.local/bin (or /usr/local/bin
# as root). Prefer _install_copilot above; this is kept for anyone who wants the
# vendor's own layout. It is fetched first and then run from disk rather than
# piped straight into a shell.
function _install_copilot_script() {
	echo "Installing copilot via the vendor install script"
	local script
	bashy_download "https://gh.io/copilot-install" script || return
	echo "running [${script}], inspect it first if you like"
	bash "${script}"
}

function _install_copilot_npm() {
	bashy_install_npm "copilot" "@github/copilot"
}

function _uninstall_copilot_npm() {
	bashy_uninstall_npm "copilot" "@github/copilot"
}

# copilot-cli is a homebrew cask, which "brew install" resolves by name
function _install_copilot_brew() {
	bashy_install_brew "copilot" "copilot-cli"
}

function _uninstall_copilot_brew() {
	bashy_uninstall_brew "copilot" "copilot-cli"
}

# The github/gh-copilot extension is archived upstream and superseded by the
# standalone copilot above. Kept for setups that still use "gh copilot".
function _install_copilot_gh() {
	bashy_install_gh_extension "copilot" "github/gh-copilot"
}

function _uninstall_copilot_gh() {
	bashy_uninstall_gh_extension "copilot" "copilot"
}

register _activate_ai_copilot
