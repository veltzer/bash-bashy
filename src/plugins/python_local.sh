# This plugin allows you to use your own folder (say "${HOME}/install/python")
# for storing modules which are not well packaged and distributed yet.
#
# If you do package all of your python modules correctly then you don't
# need this module since you can install your modules regularly either
# at the system level or at the user level.

function _activate_python_local() {
	local -n __var=$1
	local -n __error=$2
	if ! var_is_defined LOCAL_PYTHON
	then
		__error="LOCAL_PYTHON is not defined"
		__var=1
		return
	fi
	if ! checkDirectoryExists "${LOCAL_PYTHON:-}" __var __error; then return; fi
	_bashy_pathutils_add_head PYTHONPATH "${LOCAL_PYTHON:-}/bin"
	__var=0
}

register _activate_python_local
