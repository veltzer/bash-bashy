# This plugin sets up core dumping features
# why would you need it?
# default ubuntu does not come with a sane configuration for core files for
# development or instruction.
# Note that since I plug in a non absolute path for cores the kernel will complain
# on unsecure configuration.

function _activate_core() {
	local -n __var=$1
	local -n __error=$2
	ulimit -c unlimited
	# these gives warnings
	# echo core | sudo tee /proc/sys/kernel/core_pattern > /dev/null
	# echo "core.%e.%p.%t" | sudo tee /proc/sys/kernel/core_pattern > /dev/null
	local wanted="${HOME}/tmp/core.%e.%p.%t"
	# The pattern survives until reboot, so look before running sudo on every
	# shell: "read" is a builtin, and the common case is that it is already set.
	local current=""
	read -r current < /proc/sys/kernel/core_pattern 2> /dev/null
	if [ "${current}" != "${wanted}" ]
	then
		echo "${wanted}" | sudo tee /proc/sys/kernel/core_pattern > /dev/null
	fi
	__var=0
}

register _activate_core
