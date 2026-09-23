function _activate_hostaliases() {
	local -n __var=$1
	local -n __error=$2
	HOSTALIASES="${HOME}/.hostaliases"
	if ! checkReadableFile "${HOSTALIASES}" __var __error; then return; fi
	export HOSTALIASES
	__var=0
}

# Undo the activation in the running shell, for bashy_deactivate.
function _deactivate_hostaliases() {
	unset HOSTALIASES
}

register _activate_hostaliases _deactivate_hostaliases
