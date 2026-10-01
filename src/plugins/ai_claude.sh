# The api key is read from pass(1) when claude runs, not at shell start, and is
# set for that process only. This also grants claude all permissions.
function claude() {
	bashy_with_secret ANTHROPIC_API_KEY "keys/claude.ai" claude --dangerously-skip-permissions "$@"
}

function _activate_ai_claude() {
	local -n __var=$1
	local -n __error=$2
	__var=0
}

function _install_claude() {
	bashy_install_args "$@" || return
	# the vendor's native installer is Anthropic's own recommended install and the
	# one that stays in step with claude releases without waiting on a package
	# maintainer, so it is the default here; the npm and brew variants remain for
	# setups that want to manage claude through those channels
	_install_claude_native "$@"
}

# The native installer is a shell script with no release asset to download and
# verify instead, so it is fetched first and then run from disk rather than piped
# straight into a shell. It installs each release side by side under
# ~/.local/share/claude/versions and repoints the ~/.local/bin/claude symlink, so
# the same script is also the upgrade path.
function _install_claude_native() {
	bashy_install_args "$@" || return
	local executable="${HOME}/.local/bin/claude"
	local latest_version
	# the "latest" endpoint is where the vendor installer itself reads the version
	# to fetch, so ask the same source before deciding whether to run it
	latest_version=$(curl --fail --silent --location "https://downloads.claude.ai/claude-code-releases/latest" \
		| grep -oP '^[0-9]+\.[0-9]+\.[0-9]+' | head -1)
	local installed_version=""
	if [ -x "${executable}" ]
	then
		installed_version=$("${executable}" --version 2>/dev/null | grep -oP '^[0-9]+\.[0-9]+\.[0-9]+' | head -1)
	fi
	if bashy_install_check "claude" "${installed_version}" "${latest_version}"
	then
		return
	fi
	local script
	bashy_download "https://claude.ai/install.sh" script || return
	echo "running [${script}], inspect it first if you like"
	bash "${script}"
}

function _uninstall_claude_native() {
	bashy_uninstall_binary "claude" "${HOME}/.local/bin/claude"
	bashy_uninstall_directory "claude" "${HOME}/.local/share/claude"
}

function _install_claude_npm() {
	bashy_install_args "$@" || return
	bashy_install_npm "claude" "@anthropic-ai/claude-code@latest"
}

function _uninstall_claude_npm() {
	bashy_uninstall_npm "claude" "@anthropic-ai/claude-code"
}

function _install_claude_brew() {
	bashy_install_args "$@" || return
	bashy_install_brew "claude" "claude-code"
}

function _uninstall_claude_brew() {
	bashy_uninstall_brew "claude" "claude-code"
}

# The desktop app (chat, cowork and claude code in one window) is a separate
# product from the cli above. Anthropic ships it for debian/ubuntu through an apt
# repository, and the .deb registers that same repository on install, so going
# through apt is the vendor's recommended path and the one that keeps updating
# with "apt upgrade"; the direct .deb variant below is the fallback the docs give
# for when the repository cannot be registered first.
# https://code.claude.com/docs/en/desktop-linux
CLAUDE_DESKTOP_KEYRING="/usr/share/keyrings/claude-desktop-archive-keyring.asc"
CLAUDE_DESKTOP_SOURCES="/etc/apt/sources.list.d/claude-desktop.list"
CLAUDE_DESKTOP_REPO="https://downloads.claude.ai/claude-desktop/apt/stable"
# the fingerprint of Anthropic's signing key, published in the install docs; a
# key that does not match is not installed into the keyring
CLAUDE_DESKTOP_FINGERPRINT="31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE"

function _install_claude_desktop() {
	bashy_install_args "$@" || return
	_install_claude_desktop_apt "$@"
}

# recommended
#
# This does by hand what the install docs say: add Anthropic's signing key, add
# their apt repository, install claude-desktop from it. The keyring and sources
# paths are the ones the package itself registers, so there is a single entry
# for apt to find and "apt remove claude-desktop" cleans both up.
function _install_claude_desktop_apt() {
	bashy_install_args "$@" || return
	local key
	bashy_download "https://downloads.claude.ai/claude-desktop/key.asc" key || return 1
	local fingerprint
	fingerprint=$(gpg --show-keys --with-colons "${key}" 2>/dev/null | awk -F: '/^fpr:/{print $10; exit}')
	if [ "${fingerprint}" != "${CLAUDE_DESKTOP_FINGERPRINT}" ]
	then
		echo "claude-desktop: signing key fingerprint is [${fingerprint}], expected [${CLAUDE_DESKTOP_FINGERPRINT}]" >&2
		return 1
	fi
	sudo install --mode=644 "${key}" "${CLAUDE_DESKTOP_KEYRING}"
	local new_sources="deb [arch=amd64,arm64 signed-by=${CLAUDE_DESKTOP_KEYRING}] ${CLAUDE_DESKTOP_REPO} stable main"
	if [ ! -f "${CLAUDE_DESKTOP_SOURCES}" ] || [ "$(cat "${CLAUDE_DESKTOP_SOURCES}" 2>/dev/null)" != "${new_sources}" ]; then
		echo "${new_sources}" | sudo tee "${CLAUDE_DESKTOP_SOURCES}" > /dev/null
		unset _BASHY_APT_UPDATED
	fi
	bashy_install_apt "claude-desktop" "claude-desktop"
}

# The repository index lists every package it holds along with its sha256, so the
# newest .deb for this machine can be found, downloaded and verified without
# registering the repository first. Installing the .deb registers it anyway, so
# later updates still arrive through apt.
function _install_claude_desktop_deb() {
	bashy_install_args "$@" || return
	local arch
	arch=$(dpkg --print-architecture)
	local index="${CLAUDE_DESKTOP_REPO}/dists/stable/main/binary-${arch}/Packages"
	# one line per package stanza: version, pool path, digest, newest last
	local newest
	newest=$(curl --fail --silent --location "${index}" \
		| awk '/^Version:/{v=$2} /^Filename:/{f=$2} /^SHA256:/{s=$2} /^$/{if(v!="")print v, f, s; v=""} END{if(v!="")print v, f, s}' \
		| sort --version-sort | tail -n 1)
	local latest_version filename sha256
	read -r latest_version filename sha256 <<< "${newest}"
	local installed_version
	installed_version=$(dpkg-query -W -f='${Version}' claude-desktop 2>/dev/null || true)
	if bashy_install_check "claude-desktop" "${installed_version}" "${latest_version}"
	then
		return
	fi
	local url="${CLAUDE_DESKTOP_REPO}/${filename}"
	local deb
	bashy_download "${url}" deb || return 1
	bashy_verify_sha256 "${deb}" "${sha256}" || return 1
	bashy_install_deb "claude-desktop" "${url}"
}

function _uninstall_claude_desktop() {
	bashy_uninstall_apt "claude-desktop" "claude-desktop"
	# the package removes what it registered; the apt variant wrote the same files
	# by hand, so they may still be there
	local file
	for file in "${CLAUDE_DESKTOP_SOURCES}" "${CLAUDE_DESKTOP_KEYRING}"
	do
		if [ -f "${file}" ]
		then
			echo "removing ${file}"
			sudo rm -f "${file}"
		else
			echo "no ${file} detected"
		fi
	done
	sudo apt-get update
}

# Undo the activation in the running shell, for bashy_deactivate.
function _deactivate_ai_claude() {
	unset -f claude
}

register_interactive _activate_ai_claude _deactivate_ai_claude
register_install _install_claude
