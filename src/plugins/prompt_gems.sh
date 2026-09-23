# This plugin will register a function to be activated on each prompt
# to check whether a "gems/bin" folder exists in the current git repository and
# add it to the path. The logic is git_prompt_repo_path in core/git.sh, shared
# with prompt_node.

function prompt_gems() {
	git_prompt_repo_path "prompt_gems" PROMPT_GEMS_ADDED "gems/bin"
}

function _activate_prompt_gems() {
	local -n __var=$1
	local -n __error=$2
	_bashy_prompt_register prompt_gems
	__var=0
}

# Undo the activation in the running shell, for bashy_deactivate.
function _deactivate_prompt_gems() {
	_bashy_prompt_deregister prompt_gems
	if [ -n "${PROMPT_GEMS_ADDED-}" ]
	then
		_bashy_pathutils_remove PATH "${PROMPT_GEMS_ADDED}"
		unset PROMPT_GEMS_ADDED
	fi
}

register_interactive _activate_prompt_gems _deactivate_prompt_gems
