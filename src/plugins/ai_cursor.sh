# Cursor's desktop editor and terminal coding agent.
# https://cursor.com/downloads
# https://cursor.com/docs/cli/installation

function _activate_ai_cursor() {
	local -n __var=$1
	local -n __error=$2
	__var=0
}

function _cursor_arch() {
	local arch
	arch=$(uname -m)
	case "${arch}" in
		x86_64|amd64) echo "x64" ;;
		arm64|aarch64) echo "arm64" ;;
		*)
			echo "cursor: unsupported architecture [${arch}]" >&2
			return 1
			;;
	esac
}

function _install_cursor() {
	bashy_install_via _install_cursor_deb "$@" || return
	bashy_install_via _install_cursor_agent_tar "$@"
}

function _uninstall_cursor() {
	_uninstall_cursor_deb || return
	_uninstall_cursor_agent_tar
}

function _install_cursor_deb() {
	bashy_install_args "$@" || return
	if ! _bashy_pathutils_is_in_path "dpkg"
	then
		echo "cursor: the desktop installer requires dpkg" >&2
		return 1
	fi
	local arch
	arch=$(_cursor_arch) || return
	local metadata
	bashy_fetch_latest "https://cursor.com/api/download?platform=linux-${arch}&releaseTrack=stable" metadata || return
	local latest_version download_file
	latest_version=$(echo "${metadata}" | jq --raw-output '.version // empty') || return
	download_file=$(echo "${metadata}" | jq --raw-output '.debUrl // empty') || return
	if [ -z "${latest_version}" ] || [[ "${download_file}" != https://* ]]
	then
		echo "cursor: the release metadata has no version or deb url" >&2
		return 1
	fi
	local installed_version=""
	if _bashy_apt_installed "cursor"
	then
		installed_version=$(dpkg-query --show --showformat='${Version}' "cursor" 2>/dev/null) || return
		installed_version="${installed_version%%-*}"
	fi
	if bashy_install_check "cursor" "${installed_version}" "${latest_version}"
	then
		return
	fi
	bashy_install_deb "cursor" "${download_file}"
}

function _uninstall_cursor_deb() {
	bashy_uninstall_apt "cursor" "cursor"
}

function _install_cursor_agent_tar() {
	bashy_install_args "$@" || return
	local arch
	arch=$(_cursor_arch) || return
	local script
	bashy_fetch_latest "https://cursor.com/install" script || return
	# The vendor script embeds the current release in its download URL. Read
	# that version as data, never run the script. Neither release source
	# currently publishes a checksum to pass to bashy_verify_sha256.
	local latest_version
	latest_version=$(echo "${script}" | sed -nE 's@^DOWNLOAD_URL="https://downloads\.cursor\.com/lab/([^/]+)/.*@\1@p')
	if [[ ! "${latest_version}" =~ ^[0-9][0-9A-Za-z._-]*$ ]]
	then
		echo "cursor-agent: could not determine the latest version" >&2
		return 1
	fi
	local bin="${HOME}/.local/bin"
	local executable="${bin}/cursor-agent"
	local installed_version=""
	if [ -x "${executable}" ]
	then
		installed_version=$("${executable}" --version 2>/dev/null | head -1)
	fi
	if bashy_install_check "cursor-agent" "${installed_version}" "${latest_version}"
	then
		return
	fi
	local download_file="https://downloads.cursor.com/lab/${latest_version}/linux/${arch}/agent-cli-package.tar.gz"
	bashy_install_download "${download_file}"
	local tar
	bashy_download "${download_file}" tar || return
	# Keep the vendor's versioned layout and both command names, so the agent's
	# own updater can keep managing this installation.
	local versions="${HOME}/.local/share/cursor-agent/versions"
	local folder="${versions}/${latest_version}"
	mkdir -p "${versions}" || return
	local tmp_dir
	tmp_dir=$(mktemp --directory "${versions}/.tmp.XXXXXX") || return
	if ! bashy_install_extract "${tar}" "${tmp_dir}" --strip-components=1 \
		|| [ ! -x "${tmp_dir}/cursor-agent" ] || [ ! -x "${tmp_dir}/node" ] || [ ! -f "${tmp_dir}/index.js" ]
	then
		echo "cursor-agent: could not extract a complete agent package" >&2
		rm -rf "${tmp_dir}"
		return 1
	fi
	if ! rm -rf "${folder}" || ! mv "${tmp_dir}" "${folder}"
	then
		rm -rf "${tmp_dir}"
		return 1
	fi
	mkdir -p "${bin}" || return
	ln --symbolic --force --no-dereference "${folder}/cursor-agent" "${executable}" || return
	ln --symbolic --force --no-dereference "${folder}/cursor-agent" "${bin}/agent"
}

function _uninstall_cursor_agent_tar() {
	local folder="${HOME}/.local/share/cursor-agent"
	local name executable
	for name in cursor-agent agent
	do
		executable="${HOME}/.local/bin/${name}"
		# Do not remove another tool called "agent", or leave our dangling links.
		if [ -L "${executable}" ] && [[ "$(readlink "${executable}")" == "${folder}/versions/"*"/cursor-agent" ]]
		then
			echo "removing ${executable}"
			rm -f "${executable}" || return
		fi
	done
	bashy_uninstall_directory "cursor-agent" "${folder}"
}

register _activate_ai_cursor
register_install _install_cursor
