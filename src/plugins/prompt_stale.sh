# Say so when a newer bashy has been installed under this shell.
#
# The shell loaded ~/.bashy once, at startup, and keeps running that code however
# many times scripts/install_in_home.sh is run afterwards. Nothing breaks, you just
# are not running what you think you are. So on every prompt compare the install
# stamp on disk with the one read at startup, and when they differ say so, once
# per install: a second install later in the session gets a second message.
#
# The check is two builtins (a test and a read), so it costs nothing per prompt.

_BASHY_STALE_REPORTED=""

function prompt_stale() {
	local current
	_bashy_stamp_read current
	if [ "${current}" = "${_BASHY_STAMP}" ] || [ "${current}" = "${_BASHY_STALE_REPORTED}" ]
	then
		return
	fi
	_BASHY_STALE_REPORTED="${current}"
	local running="not stamped"
	if [ -n "${_BASHY_STAMP}" ]
	then
		running=$(_bashy_stamp_describe "${_BASHY_STAMP}")
	fi
	local installed="removed"
	if [ -n "${current}" ]
	then
		installed=$(_bashy_stamp_describe "${current}")
	fi
	echo "bashy: ${_BASHY_HOME} has changed since this shell started, run \"exec bash\" to pick it up" >&2
	echo "  running: ${running}" >&2
	echo "  on disk: ${installed}" >&2
}

function _activate_prompt_stale() {
	local -n __var=$1
	local -n __error=$2
	_bashy_prompt_register prompt_stale
	__var=0
}

function _deactivate_prompt_stale() {
	_bashy_prompt_deregister prompt_stale
}

register_interactive _activate_prompt_stale _deactivate_prompt_stale
