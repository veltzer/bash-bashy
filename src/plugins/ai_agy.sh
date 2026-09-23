function _activate_ai_agy() {
	local -n __var=$1
	local -n __error=$2
	# one pass(1) lookup, not two - each one is a gpg decryption costing ~35ms
	local _key
	if ! _key=$(pass show "keys/ai.google.dev" 2>/dev/null); then
		__var=$?
		__error="no pass(1) for [keys/ai.google.dev] to activate agy"
		return
	fi
	export GEMINI_API_KEY
	GEMINI_API_KEY="${_key}"
	# This is to grant agy all permissions
	alias agy="agy --dangerously-skip-permissions"
	__var=0
}

# Install the latest agy, the Google Antigravity command line coding agent.
# https://antigravity.google/cli
# Upstream's install.sh reads a per platform json manifest naming the latest
# version, its tarball and a sha512, so this does the same thing directly rather
# than running the script. It installs to ~/.local/bin/agy, where install.sh puts
# it and where agy updates itself in the background.
function _install_agy() {
	local arch
	case "$(uname -m)" in
		x86_64|amd64) arch="amd64" ;;
		arm64|aarch64) arch="arm64" ;;
		*)
			echo "agy: unsupported architecture [$(uname -m)]" >&2
			return 1
			;;
	esac
	local manifest
	if ! manifest=$(curl --fail --silent --location "https://antigravity-cli-auto-updater-974169037036.us-central1.run.app/manifests/linux_${arch}.json")
	then
		echo "agy: could not fetch the release manifest" >&2
		return 1
	fi
	local latest_version
	latest_version=$(echo "${manifest}" | jq --raw-output '.version // empty')
	local folder="${HOME}/.local/bin"
	local executable="${folder}/agy"
	local installed_version=""
	if [ -x "${executable}" ]
	then
		installed_version=$("${executable}" --version 2>/dev/null | head -1)
	fi
	if bashy_install_check "agy" "${installed_version}" "${latest_version}"
	then
		return
	fi
	local download_file
	download_file=$(echo "${manifest}" | jq --raw-output '.url // empty')
	local expected
	expected=$(echo "${manifest}" | jq --raw-output '.sha512 // empty')
	if [ -z "${download_file}" ] || [ -z "${expected}" ]
	then
		echo "agy: the release manifest has no url or sha512" >&2
		return 1
	fi
	bashy_install_download "${download_file}"
	local tar
	bashy_download "${download_file}" tar || return
	# the manifest publishes a sha512, which bashy_verify_sha256 does not speak
	local actual
	actual=$(sha512sum "${tar}" | awk '{print $1}')
	if [ "${actual,,}" != "${expected,,}" ]
	then
		echo "agy: checksum mismatch for [${tar}]" >&2
		echo "expected [${expected}]" >&2
		echo "actual [${actual}]" >&2
		return 1
	fi
	mkdir -p "${folder}"
	rm -f "${executable}"
	# the tarball holds a single binary named "antigravity"
	bashy_install_extract "${tar}" "${folder}" "antigravity" --transform 's/^antigravity$/agy/'
}

function _uninstall_agy() {
	bashy_uninstall_binary "agy" "${HOME}/.local/bin/agy"
}

register _activate_ai_agy
