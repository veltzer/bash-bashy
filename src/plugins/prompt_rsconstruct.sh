# This plugin will register a function to be activated on each prompt
# to check whether a ".rsconstruct/tools/bin" folder exists in the current git
# repository and add it to the path. The logic is git_prompt_repo_path in
# core/git.sh, shared with prompt_gems and prompt_node.

function prompt_rsconstruct() {
	git_prompt_repo_path "prompt_rsconstruct" PROMPT_RSCONSTRUCT_ADDED ".rsconstruct/tools/bin"
}

function _activate_prompt_rsconstruct() {
	local -n __var=$1
	local -n __error=$2
	_bashy_prompt_register prompt_rsconstruct
	__var=0
}

# Undo the activation in the running shell, for bashy_deactivate.
function _deactivate_prompt_rsconstruct() {
	_bashy_prompt_deregister prompt_rsconstruct
	if [ -n "${PROMPT_RSCONSTRUCT_ADDED-}" ]
	then
		_bashy_pathutils_remove PATH "${PROMPT_RSCONSTRUCT_ADDED}"
		unset PROMPT_RSCONSTRUCT_ADDED
	fi
}

register_interactive _activate_prompt_rsconstruct _deactivate_prompt_rsconstruct
