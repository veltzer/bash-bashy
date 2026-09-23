function _activate_encfs() {
	local -n __var=$1
	local -n __error=$2
	if ! checkInPath "encfs" __var __error; then return; fi
	# a plain string test: this used to run the value as a command, which works
	# for "true" and "false" and does something else for anything unset or typo'd
	if [ "${ENCFS_ENABLED:-false}" != "true" ]
	then
		__error="encfs not enabled"
		__var=1
		return
	fi
	if ! checkDirectoryExists "${ENCFS_FOLDER_CLEAR}" __var __error; then return; fi
	if ! checkDirectoryExists "${ENCFS_FOLDER_ENCRYPTED}" __var __error; then return; fi
	# mountpoint checks if the mount is already there and ensures we only mount once
	if mountpoint -q "${ENCFS_FOLDER_CLEAR}"
	then
		# __error="folder $ENCFS_FOLDER_CLEAR already mounted"
		__var=0
		return
	fi
	# the password lives in pass(1) only; fetch it at mount time and hand it over
	# on stdin so it never touches a config file or the process argument list
	local password
	if ! password=$(pass show "${ENCFS_PASS_PATH}" 2>/dev/null)
	then
		__error="could not read encfs password from pass entry ${ENCFS_PASS_PATH}"
		__var=1
		return
	fi
	echo "${password}" | encfs --stdinpass "${ENCFS_FOLDER_ENCRYPTED}" "${ENCFS_FOLDER_CLEAR}"
	__var=$?
}

function encfs_umount() {
	fusermount -u "${ENCFS_FOLDER_CLEAR}"
}

function _install_encfs() {
	bashy_install_apt "encfs" "encfs"
}

function _uninstall_encfs() {
	bashy_uninstall_apt "encfs" "encfs"
}

# Undo the activation in the running shell, for bashy_deactivate.
function _deactivate_encfs() {
	if mountpoint -q "${ENCFS_FOLDER_CLEAR:-/nonexistent}"
	then
		fusermount -u "${ENCFS_FOLDER_CLEAR}"
	fi
}

register _activate_encfs _deactivate_encfs
register_install _install_encfs
