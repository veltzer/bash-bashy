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

# Exit the currently active auto environment (if any): source its
# .auto.exit.sh and unset AUTO_ACTIVE.
function _prompt_auto_exit() {
	local auto_file_exit_full
	if var_is_defined AUTO_ACTIVE
	then
		auto_file_exit_full="${AUTO_ACTIVE}/${auto_file_exit}"
		if [ -f "${auto_file_exit_full}" ]
		then
			bashy_log "prompt_auto" "${BASHY_LOG_INFO}" "sourcing [${auto_file_exit_full}]"
			_prompt_auto_source "${auto_file_exit_full}"
		fi
		unset AUTO_ACTIVE
	fi
}

function prompt_auto() {
	local git_root auto_file_enter_full
	if ! git_is_inside
	then
		_prompt_auto_exit
		return
	fi

	git_root=""
	git_top_level git_root
	auto_file_enter_full="${git_root}/${auto_file_enter}"
	if [ -r "${auto_file_enter_full}" ]
	then
		if var_is_defined AUTO_ACTIVE
		then
			if [ "${git_root}" == "${AUTO_ACTIVE}" ]
			then
				return
			fi
			# we need to get out of a previous auto
			_prompt_auto_exit
		fi
		# we need to enter the new environment
		bashy_log "prompt_auto" "${BASHY_LOG_INFO}" "sourcing [${auto_file_enter_full}]"
		_prompt_auto_source "${auto_file_enter_full}"
		export AUTO_ACTIVE="${git_root}"
	else
		# no enter file here; get out of a previous auto if needed
		_prompt_auto_exit
	fi
}

function _activate_prompt_auto() {
	local -n __var=$1
	local -n __error=$2
	_bashy_prompt_register prompt_auto
	__var=0
}

register_interactive _activate_prompt_auto
