# This script manages your k8s environment for you
#
# Here is what it does:
# - Whenever you 'cd' into a git repo which has a .k8s.conf file in its root
# it will set it to be the current KUBECONFIG.

k8s_conf_file_name=".k8s.conf"

function prompt_k8s() {
	local git_root k8s_configuration_name
	if ! git_is_inside
	then
		if var_is_defined KUBECONFIG
		then
			bashy_log "prompt_k8s" "${BASHY_LOG_INFO}" "down"
			unset KUBECONFIG
		fi
		return
	fi

	git_root=""
	git_top_level git_root
	k8s_configuration_name="${git_root}/${k8s_conf_file_name}"
	if [ -r "${k8s_configuration_name}" ]
	then
		if ! var_is_defined KUBECONFIG
		then
			bashy_log "prompt_k8s" "${BASHY_LOG_INFO}" "up"
			export KUBECONFIG="${k8s_configuration_name}"
			return
		fi
		if [ "${KUBECONFIG}" != "${k8s_configuration_name}" ]
		then
			bashy_log "prompt_k8s" "${BASHY_LOG_INFO}" "up"
			export KUBECONFIG="${k8s_configuration_name}"
		fi
	else
		if var_is_defined KUBECONFIG
		then
			bashy_log "prompt_k8s" "${BASHY_LOG_INFO}" "down"
			unset KUBECONFIG
		fi
	fi
}

function _activate_prompt_k8s() {
	local -n __var=$1
	local -n __error=$2
	_bashy_prompt_register prompt_k8s
	__var=0
}

register_interactive _activate_prompt_k8s
