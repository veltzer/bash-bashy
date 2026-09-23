function _activate_ansible() {
	local -n __var=$1
	local -n __error=$2
	if ! checkInPath "ansible" __var __error; then return; fi
	export ANSIBLE_NOCOWS=1
	__var=0
}

function _install_ansible() {
	bashy_install_apt "ansible" "ansible"
}

function _uninstall_ansible() {
	bashy_uninstall_apt "ansible" "ansible"
}

# Undo the activation in the running shell, for bashy_deactivate.
function _deactivate_ansible() {
	unset ANSIBLE_NOCOWS
}

register _activate_ansible _deactivate_ansible
register_install _install_ansible
