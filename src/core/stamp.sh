# The install stamp: what scripts/install_in_home.sh last put into ~/.bashy.
#
# It is one line in ${_BASHY_HOME}/.stamp:
#
#   <commit>[+dirty] <version> <install time, epoch seconds>
#
# The commit and the version are for people. The install time is what makes the
# line an identity: the installer only rewrites the stamp when it copied
# something, so two stamps differ exactly when the content of ~/.bashy differs.
# That is what lets a running shell notice, on every prompt and with builtins
# only, that a newer bashy has been installed under it. A source checkout
# sourced directly has no stamp, and that reads as empty everywhere.

# _bashy_stamp_read <variable> [file]
# Put the stamp line into <variable>, or the empty string when there is no
# stamp. Builtins only: this runs on every prompt.
function _bashy_stamp_read() {
	local -n __stamp=$1
	local __file=${2:-${_BASHY_HOME}/.stamp}
	__stamp=""
	if [ -r "${__file}" ]
	then
		read -r __stamp < "${__file}" || true
	fi
}

# _bashy_stamp_describe <stamp>
# Say what a stamp line means, for messages: the commit, the version and the
# install time as a date.
function _bashy_stamp_describe() {
	local stamp=$1
	local commit version installed
	# split on spaces whatever IFS the caller runs with
	IFS=" " read -r commit version installed <<< "${stamp}"
	local when="${installed}"
	if [[ "${installed}" =~ ^[0-9]+$ ]]
	then
		printf -v when '%(%Y-%m-%d %H:%M)T' "${installed}"
	fi
	echo "version ${version}, commit ${commit}, installed ${when}"
}
