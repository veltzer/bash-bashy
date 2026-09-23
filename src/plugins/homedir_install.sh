function _activate_homedir_install() {
	local -n __var=$1
	local -n __error=$2
	LOCAL_INSTALL_BIN="${HOME}/install/bin"
	LOCAL_INSTALL_LIB="${HOME}/install/lib"
	LOCAL_INSTALL_BINARIES="${BASHY_INSTALL_DIR}"
	if ! checkDirectoryExists "${LOCAL_INSTALL_BIN}" __var __error; then return; fi
	if ! checkDirectoryExists "${LOCAL_INSTALL_LIB}" __var __error; then return; fi
	if ! checkDirectoryExists "${LOCAL_INSTALL_BINARIES}" __var __error; then return; fi
	_bashy_pathutils_add_head PATH "${LOCAL_INSTALL_BIN}"
	_bashy_pathutils_add_head LD_LIBRARY_PATH "${LOCAL_INSTALL_LIB}"
	_bashy_pathutils_add_head PATH "${LOCAL_INSTALL_BINARIES}"
	__var=0
}

register _activate_homedir_install
