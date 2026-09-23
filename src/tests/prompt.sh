source src/core/assert.sh
source src/core/array.sh

# The prompt subsystem decides what runs after every command, so a mistake here
# either breaks the prompt or silently drops part of it. bashy.sh is a whole shell
# startup when sourced, so pull the three functions out of the plugin and drive
# them directly.
function _test_prompt_load() {
	local body
	body=$(sed -n '/^function bashy_prompt()/,/^}/p;
		/^function _bashy_prompt_register/,/^}/p;
		/^function _bashy_prompt_deregister/,/^}/p' src/plugins/prompt.sh)
	eval "${body}"
}

function _test_prompt_reset() {
	unset _BASHY_PROMPT_FUNCTIONS
	_bashy_array_new _BASHY_PROMPT_FUNCTIONS
	_test_prompt_load
}

# shellcheck disable=SC2154 # created by _bashy_array_new
function testPromptRegisterAdds() {
	_test_prompt_reset
	_bashy_prompt_register "one"
	_bashy_assert_equal "${#_BASHY_PROMPT_FUNCTIONS[@]}" 1
	_bashy_assert_equal "${_BASHY_PROMPT_FUNCTIONS[0]}" "one"
}

# shellcheck disable=SC2154 # created by _bashy_array_new
function testPromptRegisterPrepends() {
	_test_prompt_reset
	_bashy_prompt_register "first"
	_bashy_prompt_register "second"
	# registration prepends on purpose, the push version is commented out in the
	# plugin. That means prompt functions run in reverse registration order, so a
	# plugin listed later in bashy.list gets to set PS1 before an earlier one.
	_bashy_assert_equal "${_BASHY_PROMPT_FUNCTIONS[0]}" "second"
	_bashy_assert_equal "${_BASHY_PROMPT_FUNCTIONS[1]}" "first"
}

# shellcheck disable=SC2154 # created by _bashy_array_new
function testPromptDeregisterRemoves() {
	_test_prompt_reset
	_bashy_prompt_register "one"
	_bashy_prompt_register "two"
	_bashy_prompt_register "three"
	_bashy_prompt_deregister "two"
	# this silently did nothing until _bashy_array_remove was fixed
	_bashy_assert_equal "${#_BASHY_PROMPT_FUNCTIONS[@]}" 2
	local joined="${_BASHY_PROMPT_FUNCTIONS[*]}"
	if [[ "${joined}" == *two* ]]
	then
		_bashy_assert_fail
	fi
}

# shellcheck disable=SC2154 # created by _bashy_array_new
function testPromptDeregisterUnknownIsHarmless() {
	_test_prompt_reset
	_bashy_prompt_register "one"
	_bashy_prompt_deregister "never_registered"
	_bashy_assert_equal "${#_BASHY_PROMPT_FUNCTIONS[@]}" 1
}

function testPromptRunsEveryFunction() {
	_test_prompt_reset
	function _test_prompt_a() { _test_prompt_marker="${_test_prompt_marker}a"; }
	function _test_prompt_b() { _test_prompt_marker="${_test_prompt_marker}b"; }
	# call both directly first. That pins down what each one does on its own, so a
	# failure below is about registration rather than about the helpers, and it
	# gives them a visible call site - a function only ever reached by name through
	# bashy_prompt reads as dead code to shellcheck.
	_test_prompt_marker=""
	_test_prompt_a
	_test_prompt_b
	_bashy_assert_equal "${_test_prompt_marker}" "ab"
	_test_prompt_marker=""
	_bashy_prompt_register "_test_prompt_a"
	_bashy_prompt_register "_test_prompt_b"
	bashy_prompt
	# both must run, and in the prepended order
	_bashy_assert_equal "${_test_prompt_marker}" "ba"
	unset -f _test_prompt_a _test_prompt_b
}

function testPromptCapturesStatus() {
	_test_prompt_reset
	function _test_prompt_seen() { _test_prompt_seen_status="${BASHY_PROMPT_STATUS}"; }
	# a direct call first, so the helper has a visible call site (see above)
	BASHY_PROMPT_STATUS=7
	_test_prompt_seen
	_bashy_assert_equal "${_test_prompt_seen_status}" 7
	_bashy_prompt_register "_test_prompt_seen"
	# the status of the command before bashy_prompt is what every prompt function
	# sees, however many of them ran before it
	( exit 3 )
	bashy_prompt
	_bashy_assert_equal "${_test_prompt_seen_status}" 3
	true
	bashy_prompt
	_bashy_assert_equal "${_test_prompt_seen_status}" 0
	unset -f _test_prompt_seen
}

function testPromptTakesStatusFromStarship() {
	_test_prompt_reset
	function _test_prompt_seen_ss() { _test_prompt_seen_status="${BASHY_PROMPT_STATUS}"; }
	# a direct call first, so the helper has a visible call site (see above)
	BASHY_PROMPT_STATUS=7
	_test_prompt_seen_ss
	_bashy_assert_equal "${_test_prompt_seen_status}" 7
	_bashy_prompt_register "_test_prompt_seen_ss"
	# under starship "$?" is already 0 when we run, and the real status is in
	# STARSHIP_CMD_STATUS. Without starship in PROMPT_COMMAND that variable is
	# ignored, so a stale one cannot leak in.
	local PROMPT_COMMAND="starship_precmd"
	# shellcheck disable=SC2034 # read by bashy_prompt
	local STARSHIP_CMD_STATUS=5
	true
	bashy_prompt
	_bashy_assert_equal "${_test_prompt_seen_status}" 5
	PROMPT_COMMAND=""
	( exit 2 )
	bashy_prompt
	_bashy_assert_equal "${_test_prompt_seen_status}" 2
	unset -f _test_prompt_seen_ss
}

function testPromptWithNothingRegistered() {
	_test_prompt_reset
	# an empty prompt list must not error, a shell would break on every command
	bashy_prompt || _bashy_assert_fail
}
