# This is a plugin which activates bash completion for various applications that
# have a programmatic support for bash completions like pandoc(1):
# 	$ eval "$(pandoc --bash-completion)"

function _activate_bash_completions_prog() {
	local -n __var=$1
	local -n __error=$2
	if ! checkInPath "pandoc" __var __error; then return; fi
	if ! bashy_completion pandoc pandoc --bash-completion
	then
		__var=1
		__error="problem in sourcing pandoc completion"
		return
	fi
	__var=0
}

# Undo the activation in the running shell, for bashy_deactivate. The completion is dropped; the functions it defined stay, unused.
function _deactivate_bash_completions_prog() {
	complete -r pandoc 2> /dev/null
}

register_interactive _activate_bash_completions_prog _deactivate_bash_completions_prog
