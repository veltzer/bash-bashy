function _activate_vim() {
	local -n __var=$1
	local -n __error=$2
	if ! checkInPath "vim" __var __error; then return; fi
	export EDITOR="vim"
	export VISUAL="vim"
	__var=0
}

# Undo the activation in the running shell, for bashy_deactivate.
function _deactivate_vim() {
	unset EDITOR VISUAL
}

register_interactive _activate_vim _deactivate_vim
