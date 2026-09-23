# plugin for https://github.com/b-ryan/powerline-shell
# you install it with pip
# I found this to be the best of all the powerlines

function _bashy_powerline_shell_prompt() {
	# PS1=$(powerline-shell $?)
	PS1=$("${POWERLINE_SHELL}" $?)
}

function _activate_powerline_shell() {
	local -n __var=$1
	local -n __error=$2
	if ! checkInPath "powerline-shell" __var __error; then return; fi
	POWERLINE_SHELL=$(which "powerline-shell")
	export POWERLINE_SHELL
	# PROMPT_COMMAND="_update_ps1; ${PROMPT_COMMAND}"
	_bashy_prompt_register _bashy_powerline_shell_prompt
	__var=0
}

function _install_powerline_shell() {
	bashy_install_pip "powerline-shell" "powerline-shell" || return
	bashy_install_apt "powerline-shell fonts" "fonts-powerline"
}

function _uninstall_powerline_shell() {
	bashy_uninstall_pip "powerline-shell" "powerline-shell"
}

register_interactive _activate_powerline_shell
register_install _install_powerline_shell
