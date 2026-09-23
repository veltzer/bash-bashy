# This is a plugin for pass(1), the standard unix password manager.
# It points pass at a store kept in the dots repository instead of the
# default ~/.password-store.

function _activate_pass() {
	local -n __var=$1
	local -n __error=$2
	if ! checkInPath "pass" __var __error; then return; fi
	export PASSWORD_STORE_DIR="${HOME}/git/dots/password-store"
	__var=0
}

# Undo the activation in the running shell, for bashy_deactivate.
function _deactivate_pass() {
	unset PASSWORD_STORE_DIR
}

register_interactive _activate_pass _deactivate_pass
