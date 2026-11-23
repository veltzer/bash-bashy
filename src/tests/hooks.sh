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

function testRegisterInstallDirectCallFailsWhenLatestIsEmpty() {
	_test_hooks_reset
	# an installer as plugins write it: a failed lookup makes it return quietly
	function _install_direct_thing() {
		bashy_install_args "$@" || return
		local latest_version=""
		if bashy_install_check "thing" "1.0" "${latest_version}"
		then
			return
		fi
		echo "downloading"
	}
	register_install "_install_direct_thing"
	# called directly, not through bashy_install, it must still fail and not install
	local out rc=0
	out=$(_install_direct_thing 2>/dev/null) || rc=$?
	_bashy_assert_equal "${rc}" 1
	_bashy_assert_equal "${out}" ""
	# registering again (a plugin sourced twice) must not wrap the wrapper
	register_install "_install_direct_thing"
	rc=0
	out=$(_install_direct_thing 2>/dev/null) || rc=$?
	_bashy_assert_equal "${rc}" 1
	# argument errors still name the installer, not its moved copy
	local err
	err=$(_install_direct_thing --froce 2>&1 >/dev/null || true)
	_bashy_assert_equal "${err}" "_install_direct_thing: unknown argument [--froce], the options are --force and --refresh"
	unset -f _install_direct_thing _bashy_orig_install_direct_thing
	bashy_install_args
	return 0
}

function testRegisterInstallDirectCallKeepsASuccessfulRun() {
	_test_hooks_reset
	function _install_ok_thing() {
		bashy_install_args "$@" || return
		if bashy_install_check "thing" "1.0" "2.0"
		then
			return
		fi
		echo "downloading"
	}
	register_install "_install_ok_thing"
	local out rc=0
	# a stale failure from an earlier run must not leak into this one
	bashy_install_check "stale" "" "" 2>/dev/null
	out=$(_install_ok_thing --refresh 2>/dev/null) || rc=$?
	_bashy_assert_equal "${rc}" 0
	_bashy_assert_equal "${out}" $'thing 1.0 is installed, upgrading to 2.0\ndownloading'
	unset -f _install_ok_thing _bashy_orig_install_ok_thing
	return 0
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
