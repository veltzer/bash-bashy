# what is this plugin for?!?

function _activate_pyenv() {
	local -n __var=$1
	local -n __error=$2
	PYENV_ROOT="${HOME}/.pyenv"
	PYENV_BIN="${PYENV_ROOT}/bin"
	if ! checkInPath "pyenv" __var __error; then return; fi
	if ! checkDirectoryExists "${PYENV_ROOT}" __var __error; then return; fi
	if ! checkDirectoryExists "${PYENV_BIN}" __var __error; then return; fi
	export PYENV_ROOT
	export PYENV_BIN
	_bashy_pathutils_add_head PATH "${PYENV_BIN}"
	eval "$(pyenv init - || true)"
	__var=0
}

register_interactive _activate_pyenv
