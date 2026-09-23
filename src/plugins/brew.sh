# This plugin will make sure you have the brew command at your disposal

function _activate_brew() {
	local -n __var=$1
	local -n __error=$2
	BREW_HOME="${HOME}/install/homebrew"
	if ! checkDirectoryExists "${BREW_HOME}" __var __error; then return; fi
	_bashy_pathutils_add_head PATH "${BREW_HOME}/bin"
	if ! checkInPath "brew" __var __error; then return; fi
	export BREW_HOME
	# these are needed for homebrew
	export HOMEBREW_PREFIX="${HOME}/install/homebrew";
	export HOMEBREW_CELLAR="${HOME}/install/homebrew/Cellar";
	export HOMEBREW_REPOSITORY="${HOME}/install/homebrew";
	__var=0
}

# https://docs.brew.sh/Installation#untar-anywhere-unsupported
# https://superuser.com/questions/619498/can-i-install-homebrew-without-sudo-privileges
function _install_brew() {
	local folder="${HOME}/install/homebrew"
	bashy_install_git "brew" "https://github.com/Homebrew/brew" "${folder}" || return
	"${folder}/bin/brew" update --force --quiet
}

function _uninstall_brew() {
	bashy_uninstall_directory "brew" "${HOME}/install/homebrew"
}

# Undo the activation in the running shell, for bashy_deactivate.
function _deactivate_brew() {
	_bashy_pathutils_remove PATH "${HOME}/install/homebrew/bin"
	unset BREW_HOME HOMEBREW_PREFIX HOMEBREW_CELLAR HOMEBREW_REPOSITORY
}

register _activate_brew _deactivate_brew
