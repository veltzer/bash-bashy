# various common checks that are done in bashy

function checkVariableDefined() {
	local variable=$1
	local -n __var2=$2
	local -n __error2=$3
	if ! declare -p "${variable}" 2> /dev/null > /dev/null
	then
		__error2="variable [${variable}] doesnt exist"
		__var2=1
		return 1
	else
		__var2=0
		return 0
	fi
}

function checkDirectoryExists() {
	local directory=$1
	local -n __var2=$2
	local -n __error2=$3
	if [[ ! -d "${directory}" ]]
	then
		__error2="directory [${directory}] doesnt exist"
		__var2=1
		return 1
	else
		__var2=0
		return 0
	fi
}

function checkExecutableFile() {
	local filename=$1
	local -n __var2=$2
	local -n __error2=$3
	if [[ -f "${filename}" ]] && [[ -x "${filename}" ]]
	then
		__var2=0
		return 0
	fi
	__error2="file [${filename}] either doesnt exist or is not executable"
	__var2=1
	return 1
}

function checkReadableFile() {
	local filename=$1
	local -n __var2=$2
	local -n __error2=$3
	if [[ -f "${filename}" ]] && [[ -r "${filename}" ]]
	then
		__var2=0
		return 0
	fi
	__error2="file [${filename}] either doesnt exist or is not readable"
	__var2=1
	return 1
}

function checkInPath() {
	local app=$1
	local -n __var2=$2
	local -n __error2=$3
	if _bashy_pathutils_is_in_path "${app}"
	then
		__var2=0
		return 0
	fi
	__error2="[${app}] is not in PATH"
	__var2=1
	return 1
}
