# This plugin makes it easier to deal with the bash prompt
# It holds a list of functions to be called on each prompt

# The exit status of the command the user just ran. It is captured once, before
# any prompt function runs, because "$?" inside the loop below is the status of
# the previous prompt function rather than of the command. prompt_error used to
# read "$?" on entry and only worked because it happened to run first.
# shellcheck disable=SC2034 # read by the prompt plugins, prompt_error among them
declare -g BASHY_PROMPT_STATUS=0

function bashy_prompt() {
	# shellcheck disable=SC2034 # read by the prompt plugins
	BASHY_PROMPT_STATUS=$?
	# starship runs us from inside starship_precmd, and the "if" it wraps that
	# call in has already reset "$?" by the time we run. It keeps the real status
	# in STARSHIP_CMD_STATUS, so take it from there when starship is the caller.
	if [[ "${PROMPT_COMMAND-}" == *starship_precmd* ]] && [ -n "${STARSHIP_CMD_STATUS-}" ]
	then
		BASHY_PROMPT_STATUS="${STARSHIP_CMD_STATUS}"
	fi
	local function
	for function in "${_BASHY_PROMPT_FUNCTIONS[@]}"
	do
		"${function}"
	done
}

function bashy_prompt_print() {
	_bashy_array_print _BASHY_PROMPT_FUNCTIONS
}

function _activate_inf_prompt() {
	local -n __var=$1
	local -n __error=$2
	_bashy_array_new _BASHY_PROMPT_FUNCTIONS
	PROMPT_COMMAND="bashy_prompt"
	__var=0
}

function _bashy_prompt_register() {
	local __function=$1
	# _bashy_array_push _BASHY_PROMPT_FUNCTIONS "${__function}"
	_BASHY_PROMPT_FUNCTIONS=("${__function}" "${_BASHY_PROMPT_FUNCTIONS[@]}")
}

function _bashy_prompt_deregister() {
	local __function=$1
	_bashy_array_remove _BASHY_PROMPT_FUNCTIONS "${__function}"
}

register_interactive _activate_inf_prompt

# This is the old prompt implementation

function old_prompt_register() {
	local __function=$1
	if declare -p PROMPT_COMMAND 2> /dev/null > /dev/null
	then
		PROMPT_COMMAND="${__function}; ${PROMPT_COMMAND}"
	else
		PROMPT_COMMAND="${__function}"
	fi
}

function old_prompt_deregister() {
	local __function=$1
	# echo "PROMPT_COMMAND is ${PROMPT_COMMAND}"
	PROMPT_COMMAND=${PROMPT_COMMAND//${__function}; /}
	# echo "PROMPT_COMMAND is ${PROMPT_COMMAND}"
}
