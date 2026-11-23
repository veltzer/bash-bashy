# This is my own invention of a NULL value in bash.
# for my purposes it is enough to say that NULL is just the string "NULL"
# in bash. This will do for now.

function _bashy_null_is_null() {
	local value=$1
	[[ "${value}" = "NULL" ]]
}

function _bashy_null_var_is_null() {
	local -n value=$1
	[[ "${value}" = "NULL" ]]
}

function _bashy_null_isnt_null() {
	local value=$1
	[[ "${value}" != "NULL" ]]
}

function _bashy_null_set_value() {
	local -n __var_null=$1
	__var_null="NULL"
}
