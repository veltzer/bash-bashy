function _activate_node() {
	local -n __var=$1
	local -n __error=$2
	NODE_HOME="${HOME}/install/node"
	if ! checkDirectoryExists "${NODE_HOME}" __var __error; then return; fi
	export NODE_HOME
	export NODE_BIN="${NODE_HOME}/bin"
	_bashy_pathutils_add_head PATH "${NODE_BIN}"
	__var=0
}

function _install_node() {
	if ! _bashy_pathutils_is_in_path "npm"
	then
		bashy_install_apt "node" "npm" || return
	else
		echo "node npm is already installed (latest)"
	fi
	if [ ! -f "${HOME}/.bash_completion.d/npm" ]
	then
		echo "Installing node npm completions"
		mkdir -p "${HOME}/.bash_completion.d"
		npm completion > "${HOME}/.bash_completion.d/npm"
	else
		echo "node npm completions are already installed (latest)"
	fi
	if [ ! -d "${HOME}/install/node/node_modules/.bin" ]
	then
		echo "Installing node node_modules folder"
		mkdir -p "${HOME}/install/node/node_modules/.bin"
	else
		echo "node node_modules folder is already installed (latest)"
	fi
}

function npm_logout() {
	sed -i "/\(registry=\|_authToken=\)/d" "${HOME}/.npmrc"
}
function _uninstall_node() {
	bashy_uninstall_directory "node" "${HOME}/install/node"
}

# Undo the activation in the running shell, for bashy_deactivate.
function _deactivate_node() {
	_bashy_pathutils_remove PATH "${HOME}/install/node/bin"
	unset NODE_HOME NODE_BIN
}

register_interactive _activate_node _deactivate_node
register_install _install_node
