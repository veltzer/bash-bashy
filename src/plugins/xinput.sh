# TODO
# - be more careful here, don't disable the touchpad if you don't have a touchpad
# - stop hardcoding the exact touchpad type
# - don't just disable the touchpad - add hotplug support that will disable the touch
# pad only when a mouse is connected and re-enable it once the mouse is disconnected.

function _activate_xinput() {
	local -n __var=$1
	local -n __error=$2
	# disable to touchpad but only if we have a touchpad
	# if we don't have an optical mouse just return
	if xinput --list --name-only | grep -q -e "^${XINPUT_DEVICE_EXISTS:-}$"
	then
		if xinput --list --name-only | grep -q -e "^${XINPUT_DEVICE:-}$"
		then
			xinput --disable "${XINPUT_DEVICE:-}"
		fi
	else
		if xinput --list --name-only | grep -q -e "^${XINPUT_DEVICE:-}$"
		then
			xinput --enable "${XINPUT_DEVICE:-}"
		fi
	fi
	__var=0
}

function xinput_activate() {
	if xinput --list --name-only | grep -q -e "^${XINPUT_DEVICE:-}$"
	then
		xinput --enable "${XINPUT_DEVICE:-}"
	fi
}

function xinput_deactivate() {
	if xinput --list --name-only | grep -q "${XINPUT_DEVICE:-}$"
	then
		xinput --disable "${XINPUT_DEVICE:-}"
	fi
}

register _activate_xinput
