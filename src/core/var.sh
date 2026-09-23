# A function that receives a variable name and a value
# and sets the variable which has that name to the value
#
# printf -v assigns by name without going through eval, so a value holding a
# quote, a dollar or a backtick lands verbatim instead of being parsed.
function var_set_by_name() {
	local __var_name=$1
	local value=$2
	printf -v "${__var_name}" '%s' "${value}"
}

# return $?
function var_is_defined() {
	local __var_name=$1
	declare -p "${__var_name}" > /dev/null 2> /dev/null
}
