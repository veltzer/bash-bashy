# This script manages your aws environment for you
#
# Here is what it does:
# - Whenever you 'cd' into a git directory it will activate the right
# aws project for you.

aws_conf_file_name=".aws.conf"

function prompt_aws() {
	# shellcheck disable=SC2034 # filled and read by name through assoc_*
	local -A aws_conf=()
	local git_root aws_home_conf_file aws_configuration_name

	if ! git_is_inside
	then
		if var_is_defined AWS_PROFILE 
		then
			bashy_log "prompt_aws" "${BASHY_LOG_INFO}" "down"
			unset AWS_PROFILE
		fi
		return
	fi

	git_root=""
	git_top_level git_root

	if [ ! -r "${git_root}/${aws_conf_file_name}" ]
	then
		if var_is_defined AWS_PROFILE 
		then
			bashy_log "prompt_aws" "${BASHY_LOG_INFO}" "down"
			unset AWS_PROFILE
		fi
		return
	fi

	aws_home_conf_file="${HOME}/${aws_conf_file_name}"
	if [ -r "${aws_home_conf_file}" ]
	then
		assoc_config_read aws_conf "${aws_home_conf_file}"
	fi
	assoc_config_read aws_conf "${git_root}/${aws_conf_file_name}"

	# get the configuration name
	aws_configuration_name=""
	assoc_get aws_conf aws_configuration_name "aws_configuration_name"

	# set the envrionment variable
	if _bashy_null_is_null "${aws_configuration_name}"
	then
		if var_is_defined AWS_PROFILE 
		then
			bashy_log "prompt_aws" "${BASHY_LOG_INFO}" "down"
			unset AWS_PROFILE
		fi
		return
	fi
	bashy_log "prompt_aws" "${BASHY_LOG_INFO}" "up"
	export AWS_PROFILE="${aws_configuration_name}"
}

function _activate_prompt_aws() {
	local -n __var=$1
	local -n __error=$2
	_bashy_prompt_register prompt_aws
	__var=0
}

register_interactive _activate_prompt_aws
