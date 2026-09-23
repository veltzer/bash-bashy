function _activate_ls() {
	local -n __var=$1
	local -n __error=$2
	# ls with colors
	eval "$(dircolors -b)"
	alias ls="ls --color=auto --literal"
	__var=0
}

# Undo the activation in the running shell, for bashy_deactivate.
function _deactivate_ls() {
	export -n LS_COLORS
	unalias ls 2> /dev/null
}

register_interactive _activate_ls _deactivate_ls
