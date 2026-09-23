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

register_interactive _activate_bash_completions_prog
