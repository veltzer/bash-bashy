function _activate_powerline() {
	local -n __var=$1
	local -n __error=$2
	EXECUTABLE="/usr/bin/powerline-daemon"
	if [ ! -x "${EXECUTABLE}" ]
	then
		__error="[${EXECUTABLE}] doesnt exist"
		__var=1
		return
	fi
	# it turns out you don't have to run the powerline daemon
	# "${EXECUTABLE}" -q
	export POWERLINE_BASH_CONTINUATION=1
	export POWERLINE_BASH_SELECT=1
	# shellcheck source=/dev/null
	if ! source /usr/share/powerline/bindings/bash/powerline.sh
	then
		__var=$?
		__error="could not source powerline.sh"
		return
	fi
	__var=0
}

function _install_powerline() {
	bashy_install_apt "powerline" "powerline" "fonts-powerline"
}

function _uninstall_powerline() {
	bashy_uninstall_apt "powerline" "powerline" "fonts-powerline"
}

register_interactive _activate_powerline
