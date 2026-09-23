# This script manages your k8s environment for you
#
# Here is what it does:
# - Whenever you 'cd' into a git repo which has a .k8s.conf file in its root
# it will set it to be the current KUBECONFIG.
#
# The watching is done by git_prompt_repo_conf in core/git.sh, shared with
# prompt_aws and prompt_gcp. This file only says what to do on the way in and out.

k8s_conf_file_name=".k8s.conf"

function _prompt_k8s_enter() {
	local conf=$1
	if [ "${KUBECONFIG-}" != "${conf}" ]
	then
		export KUBECONFIG="${conf}"
	fi
}

function _prompt_k8s_exit() {
	unset KUBECONFIG
}

function prompt_k8s() {
	git_prompt_repo_conf "prompt_k8s" PROMPT_K8S_CONF "${k8s_conf_file_name}" _prompt_k8s_enter _prompt_k8s_exit
}

function _activate_prompt_k8s() {
	local -n __var=$1
	local -n __error=$2
	_bashy_prompt_register prompt_k8s
	__var=0
}

# Undo the activation in the running shell, for bashy_deactivate.
function _deactivate_prompt_k8s() {
	_bashy_prompt_deregister prompt_k8s
	if [ -n "${PROMPT_K8S_CONF-}" ]
	then
		_prompt_k8s_exit "${PROMPT_K8S_CONF}"
		unset PROMPT_K8S_CONF
	fi
}

register_interactive _activate_prompt_k8s _deactivate_prompt_k8s
