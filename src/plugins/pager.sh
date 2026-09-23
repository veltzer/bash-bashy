# This plugin will configure a good default pager for you which is less
# and will also configure it to emit raw color codes which it does not do
# by default.
# it will also configure the PAGER environment variable to point to less
# and will configure the more command to be an alias to less


function _activate_pager() {
	local -n __var=$1
	local -n __error=$2
	export PAGER="less"
	alias more="less"
	export LESS="-R"
	__var=0
}

# Undo the activation in the running shell, for bashy_deactivate.
function _deactivate_pager() {
	unalias more 2> /dev/null
	unset PAGER LESS
}

register_interactive _activate_pager _deactivate_pager
