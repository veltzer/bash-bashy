source src/core/assert.sh
source src/core/misc.sh
source src/core/hooks.sh
source src/core/log.sh
source src/core/var.sh
source src/core/pathutils.sh
source src/core/array.sh
source src/core/git.sh
source src/plugins/prompt.sh
source src/plugins/prompt_auto.sh

# a repo whose .auto.enter.sh and .auto.exit.sh each count how often they ran
function _test_prompt_auto_repo() {
	local -n __repo=$1
	__repo=$(mktemp --directory)
	git -c init.defaultBranch=main init --quiet "${__repo}"
	mkdir -p "${__repo}/sub"
	# shellcheck disable=SC2016 # the expansions are meant for the sourced files
	echo '_test_auto_enters=$((_test_auto_enters + 1)); export _TEST_AUTO_IN=yes' > "${__repo}/.auto.enter.sh"
	# shellcheck disable=SC2016
	echo '_test_auto_exits=$((_test_auto_exits + 1)); unset _TEST_AUTO_IN' > "${__repo}/.auto.exit.sh"
	_test_auto_enters=0
	_test_auto_exits=0
	unset AUTO_ACTIVE PROMPT_AUTO_CONF _TEST_AUTO_IN
	git_is_inside_flush
}

function testPromptAutoEntersOnceAndExitsOnce() {
	local repo
	_test_prompt_auto_repo repo
	cd "${repo}/sub" || _bashy_assert_fail
	prompt_auto
	prompt_auto
	# the enter script runs once, however many prompts happen inside
	_bashy_assert_equal "${_test_auto_enters}" 1
	_bashy_assert_equal "${_TEST_AUTO_IN}" "yes"
	_bashy_assert_equal "${AUTO_ACTIVE}" "$(realpath "${repo}")"
	cd / || _bashy_assert_fail
	prompt_auto
	prompt_auto
	_bashy_assert_equal "${_test_auto_exits}" 1
	if var_is_defined AUTO_ACTIVE || var_is_defined _TEST_AUTO_IN
	then
		_bashy_assert_fail
	fi
	rm -rf "${repo}"
}

function testPromptAutoDeactivateLeavesEnvironment() {
	local repo
	_test_prompt_auto_repo repo
	_bashy_array_new _BASHY_PROMPT_FUNCTIONS
	_bashy_prompt_register prompt_auto
	cd "${repo}" || _bashy_assert_fail
	prompt_auto
	_deactivate_prompt_auto
	# deactivating while inside runs the exit script and drops the prompt hook
	_bashy_assert_equal "${_test_auto_exits}" 1
	_bashy_assert_equal "${#_BASHY_PROMPT_FUNCTIONS[@]}" 0
	if var_is_defined AUTO_ACTIVE
	then
		_bashy_assert_fail
	fi
	cd / || _bashy_assert_fail
	rm -rf "${repo}"
}
