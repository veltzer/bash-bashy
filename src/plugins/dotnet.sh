# This is a plugin for dotnet

# https://learn.microsoft.com/en-us/dotnet/core/install/linux-ubuntu
function _install_dotnet() {
	# the microsoft repository package has to land before the sdk can be installed
	local ubuntu_version
	ubuntu_version=$(lsb_release -rs)
	bashy_install_deb "microsoft apt repository" \
		"https://packages.microsoft.com/config/ubuntu/${ubuntu_version}/packages-microsoft-prod.deb" || return
	bashy_install_apt "dotnet" "dotnet-sdk-8.0"
}

function _uninstall_dotnet() {
	bashy_uninstall_apt "dotnet" "dotnet-sdk-8.0"
}

function _activate_dotnet() {
	local -n __var=$1
	local -n __error=$2
	if ! checkInPath "dotnet" __var __error; then return; fi
	complete -f -F _dotnet_bash_complete dotnet
	__var=0
}

# https://learn.microsoft.com/en-us/dotnet/core/tools/enable-tab-autocomplete
function _dotnet_bash_complete() {
	local cur="${COMP_WORDS[COMP_CWORD]}" IFS=$'\n' # On Windows you may need to use use IFS=$'\r\n'
	local candidates
	read -d '' -ra candidates < <(dotnet complete --position "${COMP_POINT}" "${COMP_LINE}" 2>/dev/null)
	read -d '' -ra COMPREPLY < <(compgen -W "${candidates[*]:-}" -- "${cur}")
}

register_install _install_dotnet
register_interactive _activate_dotnet
