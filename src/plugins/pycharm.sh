function _activate_pycharm() {
	local -n __var=$1
	local -n __error=$2
	# The jetbrains toolbox keeps builds under <app>/<channel>/<build number> and adds a
	# new directory on every update, so nothing here may be hardcoded. Find the highest
	# build number across the channels of every installed pycharm edition.
	# Only a directory that actually holds a bin/ counts as a build, otherwise leftovers
	# such as the toolbox .history directory would win the sort and break activation.
	local toolbox="${HOME}/.local/share/JetBrains/Toolbox/apps"
	PYCHARM_HOME=$({ find "${toolbox}" -maxdepth 4 -mindepth 2 -type d -name bin -path "*/PyCharm*" \
		-not -path "*/.history/*" 2>/dev/null || true; } | { sed 's|/bin$||' || true; } | { sort --version-sort || true; } | tail -1)
	if [[ -z "${PYCHARM_HOME}" ]]
	then
		__error="no pycharm build found under [${toolbox}]"
		__var=1
		return
	fi
	PYCHARM_BIN="${PYCHARM_HOME}/bin"
	if ! checkDirectoryExists "${PYCHARM_HOME}" __var __error; then return; fi
	if ! checkDirectoryExists "${PYCHARM_BIN}" __var __error; then return; fi
	export PYCHARM_HOME
	export PYCHARM_BIN
	_bashy_pathutils_add_tail PATH "${PYCHARM_BIN}"
	__var=0
}

register _activate_pycharm
