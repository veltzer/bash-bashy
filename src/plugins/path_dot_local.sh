function _activate_path_dot_local() {
	local -n __var=$1
	local -n __error=$2
	# This file deals with ~/.local/[bin|lib|man]
	# This folder is meant for local installations.
	# https://askubuntu.com/questions/14535/whats-the-local-folder-for-in-my-home-directory
	FOLDER1="${HOME}/.local/bin"
	FOLDER2="${HOME}/.local/lib"
	if ! checkDirectoryExists "${FOLDER1}" __var __error; then return; fi
	if ! checkDirectoryExists "${FOLDER2}" __var __error; then return; fi
	_bashy_pathutils_add_head PATH "${FOLDER1}"
	_bashy_pathutils_add_head LD_LIBRARY_PATH "${FOLDER2}"
	__var=0
}

# Undo the activation in the running shell, for bashy_deactivate.
function _deactivate_path_dot_local() {
	_bashy_pathutils_remove PATH "${HOME}/.local/bin"
	_bashy_pathutils_remove LD_LIBRARY_PATH "${HOME}/.local/lib"
}

register _activate_path_dot_local _deactivate_path_dot_local
