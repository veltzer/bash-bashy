# A set of functions to help with dealing with arrays

function _bashy_array_new() {
	local __user_var=$1
	declare -ga "${__user_var}=()"
}

function _bashy_array_set() {
	local -n __array_set=$1
	local pos=$2
	local value=$3
	__array_set[pos]="${value}"
}

function _bashy_array_print() {
	local -n __array_print=$1
	echo "length of array is ${#__array_print[@]}"
	for index in "${!__array_print[@]}"
	do
		echo "${index}/${__array_print[${index}]}"
	done
}

function _bashy_array_print_2() {
	local __array_print=$1
	declare -p "${__array_print}"
}

function _bashy_array_length() {
	local -n __array_length=$1
	local -n var=$2
	var=${#__array_length[@]}
}

function _bashy_array_push() {
	local -n __array_push=$1
	local var=$2
	__array_push+=("${var}")
}

function _bashy_array_pop() {
	local -n __array_pop=$1
	local -n var=$2
	var=${__array_pop[${#__array_pop[@]}-1]}
	unset "__array_pop[${#__array_pop[@]}-1]"
}

function _bashy_array_is_array() {
	local __array_name=$1
	local declare_output
	declare_output=$(declare -p "${__array_name}")
	[[ "${declare_output}" =~ "declare -a" ]]
}

function _bashy_array_find() {
	local -n __array_find=$1
	local value=$2
	local -n __array_location=$3
	__array_location=0
	for item in "${__array_find[@]}"
	do
		if [[ "${item}" = "${value}" ]]
		then
			return
		fi
		((__array_location++))
	done
	__array_location=-1
}

function _bashy_array_contains() {
	local -n __array_contains=$1
	local value=$2
	for item in "${__array_contains[@]}"
	do
		[[ "${item}" = "${value}" ]] && return 0
	done
	return 1
}

function _bashy_array_remove() {
	local -n __array_remove=$1
	local value=$2
	local -a __kept=()
	local elem
	for elem in "${__array_remove[@]}"
	do
		if [[ "${elem}" != "${value}" ]]
		then
			__kept+=("${elem}")
		fi
	done
	# assign through the nameref, this used to write to an undefined __array so the
	# caller's array was left untouched and nothing was ever removed
	__array_remove=("${__kept[@]}")
}
