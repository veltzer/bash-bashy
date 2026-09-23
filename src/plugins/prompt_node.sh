# This plugin will register a function to be activated on each prompt
# to check whether a "node_modules/.bin" folder exists in the current git
# repository and add it to the path. The logic is git_prompt_repo_path in
# core/git.sh, shared with prompt_gems.

function prompt_node() {
	git_prompt_repo_path "prompt_node" PROMPT_NODE_ADDED "node_modules/.bin"
}

function _activate_prompt_node() {
	local -n __var=$1
	local -n __error=$2
	_bashy_prompt_register prompt_node
	__var=0
}

# Undo the activation in the running shell, for bashy_deactivate.
function _deactivate_prompt_node() {
	_bashy_prompt_deregister prompt_node
	if [ -n "${PROMPT_NODE_ADDED-}" ]
	then
		_bashy_pathutils_remove PATH "${PROMPT_NODE_ADDED}"
		unset PROMPT_NODE_ADDED
	fi
}

register_interactive _activate_prompt_node _deactivate_prompt_node
