# These are helpers to help you deal with "set -e" and "set +e"
#
# You use it this way:
#
# local e
# errexit_save_and_start e
# # now set -e is in effect
# errexit_restore "${e}"
#
# The state has to come back through a named variable rather than stdout: a
# command substitution runs in a subshell, so a "set -e" performed inside one
# would be thrown away instead of reaching the caller.

# errexit_save_and_start [out_var]
# Remember whether errexit is currently on, then turn it on.
# Echoes the previous state ("on"/"off") when no out_var is given.
function errexit_save_and_start() {
	local previous="off"
	# $- lists the single letter flags of the current shell, e for errexit
	if [[ $- == *e* ]]
	then
		previous="on"
	fi
	if [[ -n "${1:-}" ]]
	then
		local -n __out=$1
		__out="${previous}"
	else
		echo "${previous}"
	fi
	set -e
}

# the name used to be misspelled "errexist", keep it working
function errexist_save_and_start() {
	errexit_save_and_start "$@"
}

# errexit_restore <saved state>
# Put errexit back the way errexit_save_and_start found it.
function errexit_restore() {
	local previous=$1
	if [[ "${previous}" = "on" ]]
	then
		set -e
	else
		set +e
	fi
}
