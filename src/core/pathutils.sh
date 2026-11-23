function _bashy_pathutils_add_head() {
	local -n __var=$1
	local add=$2
	local IFS=":"
	local -a path=("${add}")
	local -A map=()
	for DIR in ${__var}
	do
		if [[ "${DIR}" != "${add}" ]] && [[ -z "${map[${DIR}]+muhaha}" ]]
		then
			path+=("${DIR}")
			map[${DIR}]="yes"
		fi
	done
	__var=${path[*]}
}

function _bashy_pathutils_add_tail() {
	local -n __var=$1
	local add=$2
	local IFS=":"
	local -a path=()
	local -A map=()
	for DIR in ${__var}
	do
		if [[ "${DIR}" != "${add}" ]] && [[ -z "${map[${DIR}]+muhaha}" ]]
		then
			path+=("${DIR}")
			map[${DIR}]="yes"
		fi
	done
	path+=("${add}")
	__var=${path[*]}
}

function _bashy_pathutils_remove() {
	local -n __var=$1
	local remove=$2
	local IFS=":"
	local -a path=()
	local -A map=()
	for DIR in ${__var}
	do
		if [[ "${DIR}" != "${remove}" ]] && [[ -z "${map[${DIR}]+muhaha}" ]]
		then
			path+=("${DIR}")
			map[${DIR}]="yes"
		fi
	done
	__var=${path[*]}
}

function _bashy_pathutils_is_in_path() {
	local result=0
	for x in "$@"
	do
		if ! hash "${x}" 2> /dev/null
		then
			result=1
		fi
	done
	return "${result}"
}

# reduce stuff that repeats
function _bashy_pathutils_reduce() {
	local -n __var=$1
	local IFS=":"
	local -a path=()
	local -A map=()
	for DIR in ${__var}
	do
		if [[ -z "${map[${DIR}]+muhaha}" ]]
		then
			path+=("${DIR}")
			map[${DIR}]="yes"
		fi
	done
	__var=${path[*]}
}
