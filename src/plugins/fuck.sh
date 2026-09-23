function _activate_fuck() {
	local -n __var=$1
	local -n __error=$2
	if ! checkInPath "thefuck" __var __error; then return; fi
	eval "$(thefuck --alias)"
	__var=0
}

function _install_fuck() {
	bashy_install_pip "thefuck" "thefuck"
}

function _uninstall_fuck() {
	bashy_uninstall_pip "thefuck" "thefuck"
}

register_interactive _activate_fuck
register_install _install_fuck
