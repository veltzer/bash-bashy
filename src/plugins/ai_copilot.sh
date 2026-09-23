function _activate_ai_copilot() {
	local -n __var=$1
	local -n __error=$2
	# running via gh(1)
	# alias copilot="gh copilot"
	# without permission checking via gh(1)
	#alias copilot="gh copilot --allow-all-tools"
	# without permission checking via npm
	alias copilot="copilot --allow-all-tools"
	__var=0
}

# The vendor installer is a shell script with no release asset to download and
# verify instead, so it is fetched first and then run from disk rather than piped
# straight into a shell.
function _install_copilot_script() {
	echo "Installing copilot via the vendor install script"
	local script
	bashy_download "https://gh.io/copilot-install" script || return
	echo "running [${script}], inspect it first if you like"
	bash "${script}"
}

function _install_copilot_npm() {
	bashy_install_npm "copilot" "@github/copilot"
}

function _uninstall_copilot_npm() {
	bashy_uninstall_npm "copilot" "@github/copilot"
}

function _install_copilot_gh() {
	bashy_install_gh_extension "copilot" "github/gh-copilot"
}

function _uninstall_copilot_gh() {
	bashy_uninstall_gh_extension "copilot" "copilot"
}

register _activate_ai_copilot
