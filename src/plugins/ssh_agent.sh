function _activate_ssh_agent() {
	local -n __var=$1
	local -n __error=$2
	if ! checkInPath ssh-add __var __error; then return; fi
	# this will check if an ssh agent is actually running
	if ! checkVariableDefined SSH_AUTH_SOCK __var __error; then return; fi
	# gather the keys first: one ssh-add for all of them rather than one per
	# key, and none at all when there are no keys (the glob then stays literal)
	local -a keys=()
	local key
	for key in ~/.keys/*.pem
	do
		if [ -e "${key}" ]
		then
			keys+=("${key}")
		fi
	done
	if [ "${#keys[@]}" -gt 0 ]
	then
		ssh-add "${keys[@]}" 2> /dev/null
	fi
	__var=0
}

register_interactive _activate_ssh_agent
