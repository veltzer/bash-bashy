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

register_interactive _activate_prompt_node
