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

# The native installer is a shell script with no release asset to download and
# verify instead, so it is fetched first and then run from disk rather than piped
# straight into a shell.
function _install_claude_native() {
	echo "Installing claude via the native installer"
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
	bashy_install_npm "claude" "@anthropic-ai/claude-code@latest"
}

function _uninstall_claude_npm() {
	bashy_uninstall_npm "claude" "@anthropic-ai/claude-code"
}

function _install_claude_brew() {
	bashy_install_brew "claude" "claude-code"
}

function _uninstall_claude_brew() {
	bashy_uninstall_brew "claude" "claude-code"
}

register_interactive _activate_ai_claude
