# this is a plugin for zoxide
# take a look at https://github.com/ajeetdsouza/zoxide

function _activate_zoxide() {
	local -n __var=$1
	local -n __error=$2
	if ! checkInPath "zoxide" __var __error; then return; fi
	eval "$(zoxide init bash)"
	alias cd="z"
	__var=0
}

function _install_zoxide() {
	bashy_install_via _install_zoxide_apt "$@"
}

function _uninstall_zoxide() {
	_uninstall_zoxide_apt
}

function _install_zoxide_apt() {
	bashy_install_args "$@" || return
	bashy_install_apt "zoxide" "zoxide"
}

function _uninstall_zoxide_apt() {
	bashy_uninstall_apt "zoxide" "zoxide"
}

register_interactive _activate_zoxide
register_install _install_zoxide
