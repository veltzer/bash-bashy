# This is nvm integration
function _activate_nvm() {
	local -n __var=$1
	local -n __error=$2
	NVM_DIR="${HOME}/.nvm"
	if ! checkReadableFile "${NVM_DIR}/nvm.sh" __var __error; then return; fi
	if ! checkReadableFile "${NVM_DIR}/bash_completion" __var __error; then return; fi
	# shellcheck source=/dev/null
	if ! source "${NVM_DIR}/nvm.sh"
	then
		__var=$?
		__error="could not source nvm.sh"
		return
	fi
	# shellcheck source=/dev/null
	if ! source "${NVM_DIR}/bash_completion"
	then
		__var=$?
		__error="could not source nvm bash_completion"
		return
	fi
	__var=0
}

function _install_nvm() {
	bashy_install_args "$@" || return
	# TBD
	:
}

register_interactive _activate_nvm
register_install _install_nvm
