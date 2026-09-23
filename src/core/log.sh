export BASHY_LOG_NONE=0
export BASHY_LOG_CRITICAL=1
export BASHY_LOG_ERROR=2
export BASHY_LOG_INFO=3
export BASHY_LOG_WARNING=4
export BASHY_LOG_DEBUG=5

if [ -z ${BASHY_LOG_LEVEL+x} ]
then
	export BASHY_LOG_LEVEL="${BASHY_LOG_NONE}"
fi

function bashy_log() {
	if [ "$#" -ne 3 ]
	then
		echo "usage: ${FUNCNAME[0]} <plugin> <level> <message>"
		return
	fi
	local _plugin=$1
	local _level=$2
	local _message=$3
	if [ "${BASHY_LOG_LEVEL}" -ge "${_level}" ]
	then
		echo "bashy: ${_plugin}: ${_level} - ${_message}"
	fi
}

function bashy_log_none() {
	export BASHY_LOG_LEVEL="${BASHY_LOG_NONE}"
}

function bashy_log_critical() {
	export BASHY_LOG_LEVEL="${BASHY_LOG_CRITICAL}"
}

function bashy_log_error() {
	export BASHY_LOG_LEVEL="${BASHY_LOG_ERROR}"
}

function bashy_log_info() {
	export BASHY_LOG_LEVEL="${BASHY_LOG_INFO}"
}

function bashy_log_warning() {
	export BASHY_LOG_LEVEL="${BASHY_LOG_WARNING}"
}

function bashy_log_debug() {
	export BASHY_LOG_LEVEL="${BASHY_LOG_DEBUG}"
}

