function _activate_postgresql() {
	local -n __var=$1
	local -n __error=$2
	if ! checkInPath "psql" __var __error; then return; fi
	export PGDATABASE=postgres
	__var=0
}

# Undo the activation in the running shell, for bashy_deactivate.
function _deactivate_postgresql() {
	unset PGDATABASE
}

register _activate_postgresql _deactivate_postgresql
