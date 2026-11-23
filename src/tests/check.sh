source src/core/assert.sh
source src/core/check.sh
source src/core/pathutils.sh

function testCheckVariableDefined() {
	local v e
	declare -g "TEST_CHECK_VARIABLE=1"
	checkVariableDefined TEST_CHECK_VARIABLE v e || _bashy_assert_fail
	_bashy_assert_equal "${v}" 0
	unset TEST_CHECK_VARIABLE
}

function testCheckVariableNotDefined() {
	local v="" e=""
	checkVariableDefined TEST_CHECK_NO_SUCH_VARIABLE v e && _bashy_assert_fail
	_bashy_assert_equal "${v}" 1
	_bashy_assert_equal "${e}" "variable [TEST_CHECK_NO_SUCH_VARIABLE] doesnt exist"
	return 0
}

function testCheckDirectoryExists() {
	local v e
	checkDirectoryExists "${HOME}" v e || _bashy_assert_fail
	_bashy_assert_equal "${v}" 0
}

function testCheckDirectoryDoesNotExist() {
	local v="" e=""
	checkDirectoryExists "/no/such/directory/here" v e && _bashy_assert_fail
	_bashy_assert_equal "${v}" 1
	_bashy_assert_equal "${e}" "directory [/no/such/directory/here] doesnt exist"
	return 0
}

function testCheckExecutableFile() {
	local dir
	dir=$(mktemp --directory)
	echo "#!/bin/bash" > "${dir}/prog"
	chmod +x "${dir}/prog"
	local v e
	checkExecutableFile "${dir}/prog" v e || _bashy_assert_fail
	_bashy_assert_equal "${v}" 0
	rm -rf "${dir}"
}

function testCheckExecutableFileNotExecutable() {
	local dir
	dir=$(mktemp --directory)
	echo "plain" > "${dir}/prog"
	chmod -x "${dir}/prog"
	local v="" e=""
	checkExecutableFile "${dir}/prog" v e && { rm -rf "${dir}"; _bashy_assert_fail; }
	_bashy_assert_equal "${v}" 1
	rm -rf "${dir}"
	return 0
}

function testCheckReadableFile() {
	local dir
	dir=$(mktemp --directory)
	echo "content" > "${dir}/file"
	local v e
	checkReadableFile "${dir}/file" v e || _bashy_assert_fail
	_bashy_assert_equal "${v}" 0
	rm -rf "${dir}"
}

function testCheckReadableFileMissing() {
	local v="" e=""
	checkReadableFile "/no/such/file/at/all" v e && _bashy_assert_fail
	_bashy_assert_equal "${v}" 1
	return 0
}

function testCheckInPath() {
	local v e
	# bash itself is always reachable
	checkInPath "bash" v e || _bashy_assert_fail
	_bashy_assert_equal "${v}" 0
}

function testCheckNotInPath() {
	local v="" e=""
	checkInPath "no_such_program_anywhere" v e && _bashy_assert_fail
	_bashy_assert_equal "${v}" 1
	_bashy_assert_equal "${e}" "[no_such_program_anywhere] is not in PATH"
	return 0
}
