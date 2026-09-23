function _activate_nomailcheck() {
	local -n __var=$1
	local -n __error=$2
	# stop bash from checking mail
	# currently it is not needed anymore since by default
	# bash doesn't do mail checking anymore
	# References:
	# - https://www.gnu.org/software/bash/manual/html_node/Bash-Variables.html#index-MAILCHECK
	if [ -z "${MAILCHECK}" ]
	then
		__error="[${MAILCHECK}] is not set"
		__var=1
		return
	fi
	unset MAILCHECK
	__var=0
}

register_interactive _activate_nomailcheck
