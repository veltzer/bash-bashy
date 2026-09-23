function _activate_ai_chatgpt() {
	local -n __var=$1
	local -n __error=$2
	__var=0
}

# There is no chatgpt command line client to install: the url below was never a
# real one. Left in place as the marker for where such an installer would go, so
# that nobody re-adds the placeholder that downloaded from example.com as root.
function _install_chatgpt() {
	echo "chatgpt: there is no command line client to install" >&2
	return 1
}

register _activate_ai_chatgpt
