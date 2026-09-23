# plugin for pypowerline

function _prompt_pypowerline() {
	# one version
	PS1=""
	"${PYPOWERLINE}" bash

	# second version
	# PS1="$(${PYPOWERLINE} bash)"
}

function _activate_pypowerline() {
	local -n __var=$1
	local -n __error=$2
	if ! checkInPath "pypowerline" __var __error; then return; fi
	PYPOWERLINE=$(which "pypowerline")
	export PYPOWERLINE
	# PROMPT_COMMAND="_prompt_pypowerline; ${PROMPT_COMMAND}"
	PROMPT_COMMAND="${PROMPT_COMMAND} _prompt_pypowerline"
	__var=0
}

function _install_pypowerline() {
	bashy_install_pip "pypowerline" "pypowerline"
}

function _uninstall_pypowerline() {
	bashy_uninstall_pip "pypowerline" "pypowerline"
}

register_interactive _activate_pypowerline
register_install _install_pypowerline
