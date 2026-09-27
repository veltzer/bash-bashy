source src/core/assert.sh
source src/core/array.sh
source src/core/stamp.sh

# The stamp is how a running shell notices that a newer bashy was installed under
# it, and the check runs on every prompt, so it has to be right and it has to be
# quiet when nothing happened.

function testStampReadMissingIsEmpty() {
	local stamp="preset"
	_bashy_stamp_read stamp "/nonexistent/.stamp"
	_bashy_assert_equal "${stamp}" ""
}

function testStampReadFirstLine() {
	local file
	file=$(mktemp)
	printf 'abc1234 0.1.3 1700000000\nsecond line\n' > "${file}"
	local stamp
	_bashy_stamp_read stamp "${file}"
	rm -f "${file}"
	_bashy_assert_equal "${stamp}" "abc1234 0.1.3 1700000000"
}

function testStampReadDefaultsToHome() {
	local dir
	dir=$(mktemp -d)
	echo "def5678 0.1.3 1700000000" > "${dir}/.stamp"
	local _BASHY_HOME="${dir}"
	local stamp
	_bashy_stamp_read stamp
	rm -rf "${dir}"
	_bashy_assert_equal "${stamp}" "def5678 0.1.3 1700000000"
}

function testStampDescribe() {
	local out
	out=$(TZ=UTC _bashy_stamp_describe "abc1234+dirty 0.1.3 1700000000")
	_bashy_assert_equal "${out}" "version 0.1.3, commit abc1234+dirty, installed 2023-11-14 22:13"
}

function testStampDescribeKeepsOddTime() {
	# a hand written or damaged stamp must still describe, not crash the prompt
	local out
	out=$(_bashy_stamp_describe "abc1234 0.1.3 sometime")
	_bashy_assert_equal "${out}" "version 0.1.3, commit abc1234, installed sometime"
}

# the prompt function lives in a plugin that registers itself when sourced, so
# pull just the function out and drive it against a temporary ~/.bashy
function _test_stale_load() {
	local body
	body=$(sed -n '/^function prompt_stale()/,/^}/p' src/plugins/prompt_stale.sh)
	eval "${body}"
}

# Run the prompt function in this shell, not in a subshell, so that what it
# remembers survives to the next call. The message goes to stderr and stdout must
# stay clean for the prompt, so collect only stderr into _test_stale_out.
function _test_stale_run() {
	local err
	err=$(mktemp)
	prompt_stale 2>"${err}" >/dev/null
	_test_stale_out=$(<"${err}")
	rm -f "${err}"
}

function testStaleQuietWhenUnchanged() {
	_test_stale_load
	local dir
	dir=$(mktemp -d)
	echo "abc1234 0.1.3 1700000000" > "${dir}/.stamp"
	local _BASHY_HOME="${dir}"
	local _BASHY_STAMP="abc1234 0.1.3 1700000000"
	local _BASHY_STALE_REPORTED=""
	_test_stale_run
	_bashy_assert_equal "${_test_stale_out}" ""
	rm -rf "${dir}"
}

function testStaleQuietWithoutStamp() {
	# a checkout sourced directly has no stamp on either side
	_test_stale_load
	local dir
	dir=$(mktemp -d)
	local _BASHY_HOME="${dir}"
	local _BASHY_STAMP=""
	local _BASHY_STALE_REPORTED=""
	_test_stale_run
	_bashy_assert_equal "${_test_stale_out}" ""
	rm -rf "${dir}"
}

function testStaleReportsOncePerInstall() {
	_test_stale_load
	local dir
	dir=$(mktemp -d)
	local _BASHY_HOME="${dir}"
	local _BASHY_STAMP="abc1234 0.1.3 1700000000"
	local _BASHY_STALE_REPORTED=""
	echo "def5678 0.1.4 1700003600" > "${dir}/.stamp"
	_test_stale_run
	local out="${_test_stale_out}"
	if [[ "${out}" != *"exec bash"* ]] || [[ "${out}" != *"commit def5678"* ]] || [[ "${out}" != *"commit abc1234"* ]]
	then
		_bashy_assert_fail
	fi
	# the same install is not reported again on the next prompt
	_test_stale_run
	_bashy_assert_equal "${_test_stale_out}" ""
	# but a further install is
	echo "0123abc 0.1.4 1700007200" > "${dir}/.stamp"
	_test_stale_run
	out="${_test_stale_out}"
	if [[ "${out}" != *"commit 0123abc"* ]]
	then
		_bashy_assert_fail
	fi
	rm -rf "${dir}"
}

function testStaleReportsFirstStamp() {
	# a shell started from an install that predates stamping still hears about
	# the first stamped install
	_test_stale_load
	local dir
	dir=$(mktemp -d)
	local _BASHY_HOME="${dir}"
	local _BASHY_STAMP=""
	local _BASHY_STALE_REPORTED=""
	echo "def5678 0.1.4 1700003600" > "${dir}/.stamp"
	_test_stale_run
	local out="${_test_stale_out}"
	if [[ "${out}" != *"not stamped"* ]] || [[ "${out}" != *"commit def5678"* ]]
	then
		_bashy_assert_fail
	fi
	rm -rf "${dir}"
}
