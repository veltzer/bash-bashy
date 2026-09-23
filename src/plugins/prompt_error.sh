# This is an error prompt which prints a message if $? is not 0

function prompt_error() {
	local ret="${BASHY_PROMPT_STATUS}"
	local sig reason
	bashy_log "prompt_error" "${BASHY_LOG_DEBUG}" "got ret [${ret}]"
	if [ "${ret}" -ne 0 ]
	then
		if [ "${ret}" -gt 128 ] && [ "${ret}" -lt 193 ]
		then
			sig=$((ret - 128))
			reason=$(kill -l "${sig}")
			bashy_log "prompt_error" "${BASHY_LOG_INFO}" "last command exited with signal [${reason}]"
		else
			reason="${ret}"
			bashy_log "prompt_error" "${BASHY_LOG_INFO}" "last command exited with code [${reason}]"
		fi
	fi
}

function _activate_prompt_error() {
	local -n __var=$1
	local -n __error=$2
	_bashy_prompt_register prompt_error
	__var=0
}

function _deactivate_prompt_error() {
	_bashy_prompt_deregister prompt_error
}

register_interactive _activate_prompt_error _deactivate_prompt_error
