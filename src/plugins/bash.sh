# this script is where I config bash to myliking
# this does not mean aliases, just shopts and sets.

function _activate_bash() {
	local -n __var=$1
	local -n __error=$2

	# allow globstar globbing on the command line (**)
	shopt -s globstar
	# do long completions
	# shellcheck disable=SC2034 # this variable is used by the shell
	completeopt=menu,longest
	__var=0
}

# Undo the activation in the running shell, for bashy_deactivate.
function _deactivate_bash() {
	shopt -u globstar
}

register_interactive _activate_bash _deactivate_bash
