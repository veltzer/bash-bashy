source src/core/assert.sh
source src/core/array.sh
source src/core/assoc.sh
source src/core/misc.sh
source src/core/hooks.sh

# hooks registers into these globals, so each test starts from a clean set
function _test_hooks_reset() {
	unset _bashy_array_function
	unset _bashy_assoc_function
	unset _bashy_assoc_deactivate
	unset _bashy_assoc_install
	declare -g -a _bashy_array_function=()
	declare -g -A _bashy_assoc_function=()
	declare -g -A _bashy_assoc_deactivate=()
	declare -g -A _bashy_assoc_install=()
}

function testRegisterCoreRecordsFunction() {
	_test_hooks_reset
	register_core "_activate_thing" "thing"
	_bashy_assert_equal "${#_bashy_array_function[@]}" 1
	_bashy_assert_equal "${_bashy_array_function[0]}" "_activate_thing"
	_bashy_assert_equal "${_bashy_assoc_function[_activate_thing]}" "thing"
}

function testRegisterCoreKeepsOrder() {
	_test_hooks_reset
	register_core "_activate_a" "a"
	register_core "_activate_b" "b"
	register_core "_activate_c" "c"
	_bashy_assert_equal "${#_bashy_array_function[@]}" 3
	# plugins run in registration order, so the array has to preserve it
	_bashy_assert_equal "${_bashy_array_function[0]}" "_activate_a"
	_bashy_assert_equal "${_bashy_array_function[2]}" "_activate_c"
}

function testRegisterCoreRejectsDuplicate() {
	_test_hooks_reset
	register_core "_activate_dup" "dup"
	# registering the same function twice would run it twice
	( register_core "_activate_dup" "dup" ) > /dev/null 2>&1 && _bashy_assert_fail
	return 0
}

function testRegisterUsesSourceName() {
	_test_hooks_reset
	register "_activate_from_test"
	# the name is derived from the file that called register, which is this test
	_bashy_assert_equal "${_bashy_assoc_function[_activate_from_test]}" "hooks"
}

function testRegisterInstallIsNotAHook() {
	_test_hooks_reset
	register_install "_install_thing"
	# install functions are not hooks, they are only called on demand
	_bashy_assert_equal "${#_bashy_array_function[@]}" 0
}

function testRegisterInstallRemembersByPlugin() {
	_test_hooks_reset
	register_install "_install_thing"
	# keyed on the plugin name, which is the file that called register_install
	_bashy_assert_equal "${_bashy_assoc_install[hooks]}" "_install_thing"
}

function testRegisterCoreRemembersDeactivate() {
	_test_hooks_reset
	register_core "_activate_thing" "thing" "_deactivate_thing"
	_bashy_assert_equal "${_bashy_assoc_deactivate[thing]}" "_deactivate_thing"
	# the deactivate function is not a startup hook
	_bashy_assert_equal "${#_bashy_array_function[@]}" 1
}

function testRegisterWithoutDeactivateRemembersNone() {
	_test_hooks_reset
	register "_activate_plain"
	_bashy_assert_equal "${#_bashy_assoc_deactivate[@]}" 0
}

function testRegisterPassesDeactivate() {
	_test_hooks_reset
	# this second argument used to be silently dropped
	register "_activate_with_off" "_deactivate_with_off"
	_bashy_assert_equal "${_bashy_assoc_deactivate[hooks]}" "_deactivate_with_off"
}

function testRegisterInteractiveSkipsWhenNotInteractive() {
	_test_hooks_reset
	# the test suite runs non interactively, so this must register nothing
	if is_interactive
	then
		return 0
	fi
	register_interactive "_activate_interactive_thing"
	_bashy_assert_equal "${#_bashy_array_function[@]}" 0
}
