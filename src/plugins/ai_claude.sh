function _activate_ai_claude() {
	local -n __var=$1
	local -n __error=$2
	# one pass(1) lookup, not two - each one is a gpg decryption costing ~35ms
	local _key
	if ! _key=$(pass show "keys/claude.ai" 2>/dev/null); then
		__var=$?
		__error="no pass(1) for [keys/claude.ai] to activate claude.ai"
		return
	fi
	ANTHROPIC_API_KEY="${_key}"
	export ANTHROPIC_API_KEY
	alias claude="claude --dangerously-skip-permissions"
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
