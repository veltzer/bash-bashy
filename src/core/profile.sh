# Profiling and stepping of plugin activation.
#
# These used to live in core/log.sh with a comment saying they did not belong
# there. They also used to be unconditional: is_profile returned 0 always, so every
# shell paid for measuring whether or not anyone looked at the numbers, and the
# measuring itself forked "date" twice and "bc" once per plugin. At seventy plugins
# that came to roughly a second of every shell start.
#
# Both are off unless asked for. Put this in ~/.bashy.config to profile:
#
#	readonly BASHY_PROFILE=0
#
# then look at the results with bashy_status_plugins.

# is_profile
# 0 means profiling is on, 1 means off. Off unless BASHY_PROFILE says otherwise.
function is_profile() {
	if ! declare -p "BASHY_PROFILE" > /dev/null 2> /dev/null
	then
		return 1
	fi
	return "${BASHY_PROFILE:-1}"
}

# is_step
# 0 means stepping is on, 1 means off. Off unless BASHY_STEP says otherwise.
function is_step() {
	if ! declare -p "BASHY_STEP" > /dev/null 2> /dev/null
	then
		return 1
	fi
	return "${BASHY_STEP:-1}"
}
