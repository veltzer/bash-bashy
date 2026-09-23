function _activate_guile() {
	local -n __var=$1
	local -n __error=$2
	if ! checkInPath "guile" __var __error; then return; fi
	export GUILE_AUTO_COMPILE=0
	__var=0
}

function _install_guile() {
	bashy_install_apt "guile" "guile-2.2" "guile-2.2-dev"
}

function _uninstall_guile() {
	bashy_uninstall_apt "guile" "guile-2.2" "guile-2.2-dev"
}

register _activate_guile
