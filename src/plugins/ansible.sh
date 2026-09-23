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

register _activate_ansible
register_install _install_ansible
