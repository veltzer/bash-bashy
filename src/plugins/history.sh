function _activate_history() {
	local -n __var=$1
	local -n __error=$2
	# history stuff. See https://linuxhint.com/bash_command_history_usage
	HISTSIZE=10000
	HISTFILESIZE=50000
	shopt -s histappend
	__var=0
}

# Undo the activation in the running shell, for bashy_deactivate. The history sizes stay, they are harmless.
function _deactivate_history() {
	shopt -u histappend
}

register_interactive _activate_history _deactivate_history
