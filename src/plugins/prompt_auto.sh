# This plugin sources .auto.enter.sh whenever it sees it and
# .auto.exit.sh when it leaves that folder.

auto_file_enter=".auto.enter.sh"
auto_file_exit=".auto.exit.sh"

# Source a file in the current shell with errexit on, so the first failing
# command stops the rest of that script. No subshell is used, so the script's
# environment changes (vars, PATH, etc.) persist.
#
# The trick: "set -T" (functrace) propagates the ERR trap into the sourced
# script, and the ERR trap does "return 1" so a failing command returns from
# this function (stopping the rest of the script) instead of letting errexit
# unwind up into prompt_auto. Both traps restore errexit to off afterwards.
#
# Note: an interactive shell is assumed NOT to be running under "set -e"
# (it would exit on the first failing command at the prompt), so we always
# restore to "set +e" rather than tracking the prior state.
function _prompt_auto_source() {
	local auto_file="$1"
	set -T
	trap 'trap - ERR RETURN; set +e; return 1' ERR
	trap 'trap - ERR RETURN; set +e' RETURN
	set -e
	# shellcheck source=/dev/null
	source "${auto_file}"
}

# The watching for .auto.enter.sh at the repository root is done by
# git_prompt_repo_conf in core/git.sh, shared with the other conf driven prompt
# plugins. That helper calls the enter side on every prompt, so the enter side
# has to remember for itself which environment is active: AUTO_ACTIVE holds the
# root of the repository whose .auto.enter.sh was sourced, and nothing happens
# again until it changes.

function _prompt_auto_enter() {
	local enter_file=$1
	local root="${enter_file%/*}"
	if [ "${AUTO_ACTIVE-}" = "${root}" ]
	then
		return
	fi
	bashy_log "prompt_auto" "${BASHY_LOG_INFO}" "sourcing [${enter_file}]"
	_prompt_auto_source "${enter_file}"
	export AUTO_ACTIVE="${root}"
}

# Source .auto.exit.sh of the environment being left, when there is one, and
# forget AUTO_ACTIVE.
function _prompt_auto_exit() {
	local enter_file=$1
	local exit_file="${enter_file%/*}/${auto_file_exit}"
	if [ -f "${exit_file}" ]
	then
		bashy_log "prompt_auto" "${BASHY_LOG_INFO}" "sourcing [${exit_file}]"
		_prompt_auto_source "${exit_file}"
	fi
	unset AUTO_ACTIVE
}

function prompt_auto() {
	git_prompt_repo_conf "prompt_auto" PROMPT_AUTO_CONF "${auto_file_enter}" _prompt_auto_enter _prompt_auto_exit
}

function _activate_prompt_auto() {
	local -n __var=$1
	local -n __error=$2
	_bashy_prompt_register prompt_auto
	__var=0
}

# Undo the activation in the running shell, for bashy_deactivate.
function _deactivate_prompt_auto() {
	_bashy_prompt_deregister prompt_auto
	if [ -n "${PROMPT_AUTO_CONF-}" ]
	then
		_prompt_auto_exit "${PROMPT_AUTO_CONF}"
		unset PROMPT_AUTO_CONF
	fi
}

register_interactive _activate_prompt_auto _deactivate_prompt_auto
