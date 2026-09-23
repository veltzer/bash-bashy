source src/core/assert.sh
source src/core/source.sh

# a file that counts how often it was sourced
function _test_source_file() {
	local -n __file=$1
	local dir
	dir=$(mktemp --directory)
	__file="${dir}/counted.sh"
	# shellcheck disable=SC2016 # the expansion is meant for the sourced file
	echo '_test_source_count=$((_test_source_count + 1))' > "${__file}"
}

function testSourceAbsoluteOnce() {
	local file
	_test_source_file file
	_test_source_count=0
	_bashy_source_absolute "${file}"
	_bashy_source_absolute "${file}"
	# the guard is the whole point of the function
	_bashy_assert_equal "${_test_source_count}" 1
	rm -rf "${file%/*}"
}

function testSourceAbsoluteRelativeSpellings() {
	local file
	_test_source_file file
	_test_source_count=0
	# the same file as "./x", "x" and "/abs/x" is one file, without realpath(1)
	( cd "${file%/*}" && _bashy_source_absolute "./counted.sh" && _bashy_source_absolute "counted.sh" \
		&& _bashy_source_absolute "${file}" && [ "${_test_source_count}" = 1 ] ) || _bashy_assert_fail
	rm -rf "${file%/*}"
}

function testSourceAbsoluteMissingFails() {
	if _bashy_source_absolute "/no/such/file.sh" 2>/dev/null
	then
		_bashy_assert_fail
	fi
	return 0
}
