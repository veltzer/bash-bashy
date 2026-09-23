function _activate_git() {
	local -n __var=$1
	local -n __error=$2
	if ! checkInPath "git" __var __error; then return; fi
	# /etc/bash_completions also has this so this is sometimes redundant
	if ! source /usr/share/bash-completion/completions/git
	then
		__var=1
		__error="problem in sourcing git completion"
		return
	fi
	__var=0
}

register_interactive _activate_git
