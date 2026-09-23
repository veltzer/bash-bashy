# This is integration of angular.js (ng on the command line)
function _activate_ng() {
	local -n __var=$1
	local -n __error=$2
	if ! checkInPath "ng" __var __error; then return; fi
	if ! bashy_completion ng ng completion script
	then
		__var=$?
		__error="could not source ng completion script"
	fi
	__var=0
}

function _install_ng() {
	bashy_install_npm "ng" "@angular/cli"
}

function _uninstall_ng() {
	bashy_uninstall_npm "ng" "@angular/cli"
}

register_interactive _activate_ng
