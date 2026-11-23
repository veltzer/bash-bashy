function _activate_pureline() {
	local -n __var=$1
	local -n __error=$2
	PURELINE="${HOME}/install/pureline/pureline"
	if [[ ! -r "${PURELINE}" ]]
	then
		__error="[${PURELINE}] doesnt exist"
		__var=1
		return
	fi
	# shellcheck source=/dev/null
	if ! source "${HOME}/install/pureline/pureline" "${HOME}/.pureline.conf"
	then
		__var=$?
		__error="could not source ${HOME}/install/pureline/pureline or ${HOME}/.pureline.conf"
		return
	fi
	__var=0
}

register_interactive _activate_pureline
