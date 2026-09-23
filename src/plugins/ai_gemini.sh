# This is integration of gemini, the Google command line coding tool
# https://github.com/google-gemini/gemini-cli
# The api key is read from pass(1) when gemini runs, not at shell start, and is
# set for that process only. This also grants gemini all permissions.
function gemini() {
	bashy_with_secret GEMINI_API_KEY "keys/ai.google.dev" gemini --yolo "$@"
}

function _activate_ai_gemini() {
	local -n __var=$1
	local -n __error=$2
	__var=0
}

# Install the latest stable Gemini CLI.
# https://geminicli.com/docs/get-started/installation/
function _install_gemini() {
	local package="@google/gemini-cli"
	if ! _bashy_pathutils_is_in_path "npm"
	then
		echo "gemini: npm not found - install node first" >&2
		return 1
	fi
	local latest_version
	latest_version=$(npm view "${package}" version 2>/dev/null)
	# --parseable --long prints "<path>:<package>@<version>", or nothing when
	# the package is not installed globally
	local installed_version
	installed_version=$(npm ls --global --depth=0 --parseable --long "${package}" 2>/dev/null | sed -n "s|^.*:${package}@||p")
	if bashy_install_check "gemini" "${installed_version}" "${latest_version}"
	then
		return
	fi
	bashy_install_npm "gemini" "${package}@${latest_version:-latest}"
}

function _uninstall_gemini() {
	bashy_uninstall_npm "gemini" "@google/gemini-cli"
}

# Undo the activation in the running shell, for bashy_deactivate.
function _deactivate_ai_gemini() {
	unset -f gemini
}

register_interactive _activate_ai_gemini _deactivate_ai_gemini
