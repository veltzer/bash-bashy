source src/core/assert.sh
source src/core/var.sh
source src/core/log.sh
source src/core/pathutils.sh
source src/core/git.sh

# a throwaway repository to ask questions about, with a folder in it that
# git_prompt_repo_path can pick up
function _test_git_repo() {
	local -n __dir=$1
	__dir=$(mktemp --directory)
	git -c init.defaultBranch=main init --quiet "${__dir}"
	mkdir -p "${__dir}/sub" "${__dir}/gems/bin"
}

function testGitIsInsideRepo() {
	local repo
	_test_git_repo repo
	git_is_inside_flush
	( cd "${repo}/sub" && git_is_inside ) || _bashy_assert_fail
	rm -rf "${repo}"
}

function testGitIsInsideNotRepo() {
	local dir
	dir=$(mktemp --directory)
	git_is_inside_flush
	# a fresh temp dir is not inside a repository (unless /tmp is one)
	if ( cd "${dir}" && git_is_inside )
	then
		[ -e "${dir}/../.git" ] || _bashy_assert_fail
	fi
	rm -rf "${dir}"
}

function testGitIsInsideRemembers() {
	local repo
	_test_git_repo repo
	git_is_inside_flush
	cd "${repo}" || _bashy_assert_fail
	git_is_inside || _bashy_assert_fail
	# the answer is remembered per directory, so the cache has our entry
	_bashy_assert_equal "${_bashy_git_inside_cache[${PWD}]}" 0
	git_is_inside_flush
	_bashy_assert_equal "${#_bashy_git_inside_cache[@]}" 0
	cd / || _bashy_assert_fail
	rm -rf "${repo}"
}

function testGitTopLevel() {
	local repo top
	_test_git_repo repo
	cd "${repo}/sub" || _bashy_assert_fail
	git_top_level top
	_bashy_assert_equal "${top}" "$(realpath "${repo}")"
	cd / || _bashy_assert_fail
	rm -rf "${repo}"
}

function testGitTopLevelRemembers() {
	local repo top
	_test_git_repo repo
	git_is_inside_flush
	cd "${repo}/sub" || _bashy_assert_fail
	git_top_level top
	# the answer is remembered per directory, and the flush forgets it
	_bashy_assert_equal "${_bashy_git_top_cache[${PWD}]}" "${top}"
	_bashy_git_top_cache[${PWD}]="/remembered"
	git_top_level top
	_bashy_assert_equal "${top}" "/remembered"
	git_is_inside_flush
	_bashy_assert_equal "${#_bashy_git_top_cache[@]}" 0
	git_top_level top
	_bashy_assert_equal "${top}" "$(realpath "${repo}")"
	cd / || _bashy_assert_fail
	rm -rf "${repo}"
}

function testGitRepoName() {
	local repo name
	_test_git_repo repo
	cd "${repo}/sub" || _bashy_assert_fail
	# this called a misspelled git_top_levl and failed on every use
	git_repo_name name
	_bashy_assert_equal "${name}" "${repo##*/}"
	cd / || _bashy_assert_fail
	rm -rf "${repo}"
}

function testGitRootGoesToTop() {
	local repo
	_test_git_repo repo
	cd "${repo}/sub" || _bashy_assert_fail
	git_root
	_bashy_assert_equal "$(realpath "${PWD}")" "$(realpath "${repo}")"
	cd / || _bashy_assert_fail
	rm -rf "${repo}"
}

function testGitRootOutsideRepoReturns() {
	local dir
	dir=$(mktemp --directory)
	# this used to "exit", which took the interactive shell down with it. Run it
	# in a subshell that echoes afterwards: the echo is only reached on a return.
	local after
	after=$(cd "${dir}" && git_root 2>/dev/null; echo "still here")
	if [[ "${after}" != *"still here"* ]] && [ ! -e "${dir}/../.git" ]
	then
		_bashy_assert_fail
	fi
	rm -rf "${dir}"
}

function testGitPromptRepoPathAddsAndRemoves() {
	local repo
	_test_git_repo repo
	git_is_inside_flush
	local saved_path="${PATH}"
	unset TEST_REPO_PATH_ADDED
	cd "${repo}/sub" || _bashy_assert_fail
	git_prompt_repo_path "test" TEST_REPO_PATH_ADDED "gems/bin"
	_bashy_assert_equal "${TEST_REPO_PATH_ADDED}" "$(realpath "${repo}")/gems/bin"
	_bashy_assert_equal "${PATH%%:*}" "$(realpath "${repo}")/gems/bin"
	# a second prompt in the same repo changes nothing
	git_prompt_repo_path "test" TEST_REPO_PATH_ADDED "gems/bin"
	_bashy_assert_equal "${PATH%%:*}" "$(realpath "${repo}")/gems/bin"
	# leaving the repo takes it off again
	cd / || _bashy_assert_fail
	git_prompt_repo_path "test" TEST_REPO_PATH_ADDED "gems/bin"
	if var_is_defined TEST_REPO_PATH_ADDED
	then
		_bashy_assert_fail
	fi
	if [[ ":${PATH}:" == *":${repo}/gems/bin:"* ]]
	then
		_bashy_assert_fail
	fi
	PATH="${saved_path}"
	rm -rf "${repo}"
}

function testGitPromptRepoPathMissingFolder() {
	local repo
	_test_git_repo repo
	git_is_inside_flush
	local saved_path="${PATH}"
	unset TEST_REPO_PATH_ADDED
	cd "${repo}" || _bashy_assert_fail
	git_prompt_repo_path "test" TEST_REPO_PATH_ADDED "node_modules/.bin"
	if var_is_defined TEST_REPO_PATH_ADDED
	then
		_bashy_assert_fail
	fi
	_bashy_assert_equal "${PATH}" "${saved_path}"
	cd / || _bashy_assert_fail
	rm -rf "${repo}"
}

# the enter and exit sides record what they were called with
function _test_conf_enter() { _test_conf_log="${_test_conf_log}enter:${1##*/};"; }
function _test_conf_exit() { _test_conf_log="${_test_conf_log}exit:${1##*/};"; }

function testGitPromptRepoConfEntersExits() {
	local repo
	_test_git_repo repo
	git_is_inside_flush
	unset TEST_CONF_ACTIVE
	_test_conf_log=""
	# direct calls first, so the helpers have a visible call site
	_test_conf_enter "/x/a"
	_test_conf_exit "/x/a"
	_bashy_assert_equal "${_test_conf_log}" "enter:a;exit:a;"
	_test_conf_log=""
	cd "${repo}/sub" || _bashy_assert_fail
	# no conf file yet: nothing happens
	git_prompt_repo_conf "test" TEST_CONF_ACTIVE ".t.conf" _test_conf_enter _test_conf_exit
	_bashy_assert_equal "${_test_conf_log}" ""
	touch "${repo}/.t.conf"
	# enter runs on every prompt that finds the file, so an edit is seen
	git_prompt_repo_conf "test" TEST_CONF_ACTIVE ".t.conf" _test_conf_enter _test_conf_exit
	git_prompt_repo_conf "test" TEST_CONF_ACTIVE ".t.conf" _test_conf_enter _test_conf_exit
	_bashy_assert_equal "${_test_conf_log}" "enter:.t.conf;enter:.t.conf;"
	_bashy_assert_equal "${TEST_CONF_ACTIVE}" "$(realpath "${repo}")/.t.conf"
	# leaving runs exit exactly once, with the file that was active
	cd / || _bashy_assert_fail
	git_prompt_repo_conf "test" TEST_CONF_ACTIVE ".t.conf" _test_conf_enter _test_conf_exit
	git_prompt_repo_conf "test" TEST_CONF_ACTIVE ".t.conf" _test_conf_enter _test_conf_exit
	_bashy_assert_equal "${_test_conf_log}" "enter:.t.conf;enter:.t.conf;exit:.t.conf;"
	if var_is_defined TEST_CONF_ACTIVE
	then
		_bashy_assert_fail
	fi
	rm -rf "${repo}"
}

function testGitPromptRepoConfFileRemoved() {
	local repo
	_test_git_repo repo
	git_is_inside_flush
	unset TEST_CONF_ACTIVE
	_test_conf_log=""
	cd "${repo}" || _bashy_assert_fail
	touch "${repo}/.t.conf"
	git_prompt_repo_conf "test" TEST_CONF_ACTIVE ".t.conf" _test_conf_enter _test_conf_exit
	# the file going away while still inside the repo is a leave as well
	rm "${repo}/.t.conf"
	git_prompt_repo_conf "test" TEST_CONF_ACTIVE ".t.conf" _test_conf_enter _test_conf_exit
	_bashy_assert_equal "${_test_conf_log}" "enter:.t.conf;exit:.t.conf;"
	cd / || _bashy_assert_fail
	rm -rf "${repo}"
}
