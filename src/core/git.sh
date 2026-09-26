# This is a set of git bash functions

# a function that returns whether or not the current working directory
# is inside a git tree
#
# The prompt plugins ask this on every single prompt, through git_prompt_repo_path
# and git_prompt_repo_conf below, and each answer used to fork "git rev-parse", so
# the same question cost about 28 ms per prompt. The answer only depends on the
# directory, so remember it per directory.
#
# The memo is keyed on PWD alone. Creating or removing a repository under a
# directory you are already sitting in is rare enough, and "git_is_inside_flush"
# is there for when it happens.
declare -gA _bashy_git_inside_cache=()

function git_is_inside() {
	if [ -n "${_bashy_git_inside_cache[${PWD}]+x}" ]
	then
		return "${_bashy_git_inside_cache[${PWD}]}"
	fi
	local result err
	result=$(git rev-parse --is-inside-work-tree 2> /dev/null)
	err="${?}"
	if [ "${err}" != 0 ]
	then
		_bashy_git_inside_cache[${PWD}]="${err}"
		return "${err}"
	fi
	[ "${result}" = "true" ]
	local err2="${?}"
	_bashy_git_inside_cache[${PWD}]="${err2}"
	return "${err2}"
}

# the top level of the repository PWD is in, remembered per directory like the
# answer above: the same prompt helpers ask for it on every prompt
declare -gA _bashy_git_top_cache=()

# forget what git_is_inside and git_top_level remembered, for when a repository
# appears or disappears under a directory that has already been visited
function git_is_inside_flush() {
	_bashy_git_inside_cache=()
	_bashy_git_top_cache=()
}

# returns the top level of a git tree
#
# The names here carry the function's name so that a caller which is itself
# holding a nameref (git_repo_name below) or a variable called "toplevel" does
# not clash with them: two nested "local -n __var" resolve to the same variable,
# and the inner assignment lands in the wrong place.
function git_top_level() {
	local -n __git_top_level_var=$1
	if [ -n "${_bashy_git_top_cache[${PWD}]+x}" ]
	then
		__git_top_level_var="${_bashy_git_top_cache[${PWD}]}"
		return 0
	fi
	local __git_top_level_result
	__git_top_level_result=$(git rev-parse --show-toplevel) || return 1
	_bashy_git_top_cache[${PWD}]="${__git_top_level_result}"
	__git_top_level_var="${__git_top_level_result}"
}

# returns the name of the current git repo
function git_repo_name() {
	local -n __git_repo_name_var=$1
	local toplevel
	git_top_level toplevel
	__git_repo_name_var="${toplevel##*/}"
}

# go to the root of the current git repo
#
# This is called from an interactive shell, so a failure has to "return", never
# "exit": the exit would take the whole shell with it.
function git_root() {
	# the "git rev-parse" will also print an error if not inside a git repo
	local cd_arg
	cd_arg="$(git rev-parse --show-cdup)" || return 1
	if [ -n "${cd_arg}" ]
	then
		cd "${cd_arg}" || return 1
	fi
}

# git_prompt_repo_path <log tag> <variable> <subdir>
# Keep <repo root>/<subdir> at the head of PATH while inside a git repository
# that has that folder, and take it off again on the way out. <variable> is the
# exported variable that remembers what was added, so the next prompt knows what
# to remove. Meant to be called from a prompt function, once per prompt.
#
# prompt_gems and prompt_node were the same forty lines with a different folder
# name, so the logic lives here once and each of them is a one line call.
function git_prompt_repo_path() {
	local tag=$1
	local name=$2
	local subdir=$3
	local wanted=""
	if git_is_inside
	then
		local root
		git_top_level root
		if [ -d "${root}/${subdir}" ]
		then
			wanted="${root}/${subdir}"
		fi
	fi
	local current="${!name-}"
	if [ "${current}" = "${wanted}" ]
	then
		return
	fi
	if [ -n "${current}" ]
	then
		bashy_log "${tag}" "${BASHY_LOG_INFO}" "down"
		_bashy_pathutils_remove PATH "${current}"
		unset "${name}"
	fi
	if [ -n "${wanted}" ]
	then
		bashy_log "${tag}" "${BASHY_LOG_INFO}" "up"
		export "${name}=${wanted}"
		_bashy_pathutils_add_head PATH "${wanted}"
	fi
}

# git_prompt_repo_conf <log tag> <variable> <file name> <enter function> <exit function>
# Watch for <file name> at the root of the git repository PWD is in.
#
# On every prompt that finds the file, <enter function> runs with its path. That
# is every prompt, not only the first one, so a plugin that reads the file sees an
# edit at the next prompt; keep it cheap and idempotent. On the first prompt that
# no longer finds it, whether because PWD left the repository or the file went
# away, <exit function> runs once. <variable> is the exported variable that
# remembers the active file across prompts, so the exit side also works in a
# child shell started inside the repository.
#
# prompt_aws, prompt_k8s and prompt_gcp each carried this state machine by hand,
# and each copy had the same bugs. Meant to be called from a prompt function.
function git_prompt_repo_conf() {
	local tag=$1
	local name=$2
	local file=$3
	local enter=$4
	local exit=$5
	local wanted=""
	if git_is_inside
	then
		local root
		git_top_level root
		if [ -r "${root}/${file}" ]
		then
			wanted="${root}/${file}"
		fi
	fi
	local current="${!name-}"
	if [ -n "${current}" ] && [ "${current}" != "${wanted}" ]
	then
		bashy_log "${tag}" "${BASHY_LOG_INFO}" "down"
		"${exit}" "${current}"
		unset "${name}"
	fi
	if [ -n "${wanted}" ]
	then
		if [ "${current}" != "${wanted}" ]
		then
			bashy_log "${tag}" "${BASHY_LOG_INFO}" "up"
			export "${name}=${wanted}"
		fi
		"${enter}" "${wanted}"
	fi
}
