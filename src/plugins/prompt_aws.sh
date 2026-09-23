# This script manages your aws environment for you
#
# Here is what it does:
# - Whenever you 'cd' into a git directory that has a .aws.conf file in its root
# it will activate the aws profile named in it.
#
# The watching is done by git_prompt_repo_conf in core/git.sh, shared with
# prompt_k8s and prompt_gcp. This file only says what to do on the way in and out.

aws_conf_file_name=".aws.conf"

# runs on every prompt inside the repo, so an edit to .aws.conf shows at the next
# prompt. Reading the file is builtin "read", no process is spawned.
function _prompt_aws_enter() {
	local conf=$1
	# shellcheck disable=SC2034 # filled and read by name through assoc_*
	local -A aws_conf=()
	# ~/.aws.conf supplies defaults, the repo file overrides them
	local home_conf="${HOME}/${aws_conf_file_name}"
	if [ -r "${home_conf}" ]
	then
		assoc_config_read aws_conf "${home_conf}"
	fi
	assoc_config_read aws_conf "${conf}"
	local profile=""
	assoc_get aws_conf profile "aws_configuration_name"
	if _bashy_null_is_null "${profile}"
	then
		unset AWS_PROFILE
		return
	fi
	if [ "${AWS_PROFILE-}" != "${profile}" ]
	then
		export AWS_PROFILE="${profile}"
	fi
}

function _prompt_aws_exit() {
	unset AWS_PROFILE
}

function prompt_aws() {
	git_prompt_repo_conf "prompt_aws" PROMPT_AWS_CONF "${aws_conf_file_name}" _prompt_aws_enter _prompt_aws_exit
}

function _activate_prompt_aws() {
	local -n __var=$1
	local -n __error=$2
	_bashy_prompt_register prompt_aws
	__var=0
}

# Undo the activation in the running shell, for bashy_deactivate.
function _deactivate_prompt_aws() {
	_bashy_prompt_deregister prompt_aws
	if [ -n "${PROMPT_AWS_CONF-}" ]
	then
		_prompt_aws_exit "${PROMPT_AWS_CONF}"
		unset PROMPT_AWS_CONF
	fi
}

register_interactive _activate_prompt_aws _deactivate_prompt_aws
