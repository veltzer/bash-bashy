# This file defines helpers for dealing with associative arrays
# in bash
#
# References:
# - http://www.artificialworlds.net/blog/2012/10/17/bash-associative-array-examples/
# - https://stackoverflow.com/questions/23167047/bash-parse-arrays-from-config-file


# This is a function that creates a new global associative array in a variable
# name of your choosing.
# Note the -g flag which makes a global associative array. It is necessary,
# otherwise the associative array which is created will be local.
function assoc_new() {
	local __user_var=$1
	declare -gA "${__user_var}=()"
}

# This is a function that returns an associative arrays length
function assoc_len() {
	local -n __assoc_len=$1
	local -n __var=$2
	__var=${#__assoc_len[@]}
}

# This is a function to print out an associative array.
# It has been checked to handle associative arrays which have spaces
# in the keys or values correctly.
function assoc_print() {
	local -n __assoc_print=$1
	local key
	for key in "${!__assoc_print[@]}"
	do
		local val=${__assoc_print[${key}]}
		echo "${key} --> ${val}"
	done
}

function assoc_set() {
	local -n __assoc_set=$1
	local key=$2
	local value=$3
	# shellcheck disable=2004
	__assoc_set[${key}]="${value}"
}

function assoc_get() {
	local -n __assoc_get=$1
	local -n __var=$2
	local key=$3
	if assoc_key_exists __assoc_get "${key}"
	then
		__var=${__assoc_get[${key}]}
	else
		_bashy_null_set_value __var
	fi
}

function assoc_config_read() {
	local -n __assoc_config_read=$1
	local filename=$2
	while read -r line
	do
		if [[ "${line}" =~ ^([_[:alpha:]][_[:alnum:]]*)"="(.*) ]]
		then
			assoc_set __assoc_config_read "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
		fi
	done < "${filename}"
}

function assoc_key_exists() {
	local -n __assoc_key_exists=$1
	local key=$2
	[ -n "${__assoc_key_exists[${key}]+muhaha}" ]
}

function assoc_assert_key_exists() {
	local -n __assoc_assert_key_exists=$1
	local key=$2
	if ! assoc_key_exists __assoc_assert_key_exists "${key}"
	then
		_bashy_assert_fail
	fi
}

function assoc_assert_key_not_exists() {
	local -n __assoc_assert_key_not_exists=$1
	local key=$2
	if assoc_key_exists __assoc_assert_key_not_exists "${key}"
	then
		_bashy_assert_fail
	fi
}
