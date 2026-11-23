source src/core/assert.sh
source src/core/null.sh
source src/core/array.sh
source src/core/assoc.sh

# The plugin list parser is the code that decides which plugins run and in what
# order, so it is the piece most able to break a user's shell. It lives in
# bashy.sh, which is a whole startup when sourced, so pull just that function out
# and drive it directly.
function _test_runtime_load_parser() {
	local body
	body=$(sed -n '/^function _bashy_read_plugins_filename/,/^}/p' src/bashy.sh)
	eval "${body}"
}

function _test_runtime_reset() {
	unset bashy_array_plugin
	unset bashy_assoc_enabled
	_bashy_array_new bashy_array_plugin
	assoc_new bashy_assoc_enabled
}

function _test_runtime_parse() {
	local content=$1
	local file
	file=$(mktemp)
	printf '%s' "${content}" > "${file}"
	_test_runtime_load_parser
	_test_runtime_reset
	_bashy_read_plugins_filename "${file}"
	rm -f "${file}"
}

# shellcheck disable=SC2154 # globals created by _test_runtime_reset
function testReadPluginsPlainNames() {
	_test_runtime_parse 'alpha
beta
gamma
'
	_bashy_assert_equal "${#bashy_array_plugin[@]}" 3
	_bashy_assert_equal "${bashy_array_plugin[0]}" "alpha"
	_bashy_assert_equal "${bashy_array_plugin[2]}" "gamma"
}

# shellcheck disable=SC2154 # globals created by _test_runtime_reset
function testReadPluginsKeepsOrder() {
	# plugins run in file order and some of them depend on it, the aws/gcp/env
	# comment in bashy.list says so explicitly
	_test_runtime_parse 'zulu
alpha
mike
'
	_bashy_assert_equal "${bashy_array_plugin[0]}" "zulu"
	_bashy_assert_equal "${bashy_array_plugin[1]}" "alpha"
	_bashy_assert_equal "${bashy_array_plugin[2]}" "mike"
}

# shellcheck disable=SC2154 # globals created by _test_runtime_reset
function testReadPluginsEnabledByDefault() {
	_test_runtime_parse 'alpha
'
	_bashy_assert_equal "${bashy_assoc_enabled[alpha]}" 1
}

# shellcheck disable=SC2154 # globals created by _test_runtime_reset
function testReadPluginsMinusDisables() {
	# a leading minus is how a plugin is turned off without deleting the line
	_test_runtime_parse 'alpha
-beta
gamma
'
	_bashy_assert_equal "${#bashy_array_plugin[@]}" 3
	_bashy_assert_equal "${bashy_assoc_enabled[alpha]}" 1
	_bashy_assert_equal "${bashy_assoc_enabled[beta]}" 0
	_bashy_assert_equal "${bashy_assoc_enabled[gamma]}" 1
	# the name must have the minus stripped, or the plugin file is never found
	_bashy_assert_equal "${bashy_array_plugin[1]}" "beta"
}

# shellcheck disable=SC2154 # globals created by _test_runtime_reset
function testReadPluginsSkipsComments() {
	_test_runtime_parse '# a comment
alpha
# another one
beta
'
	_bashy_assert_equal "${#bashy_array_plugin[@]}" 2
	_bashy_assert_equal "${bashy_array_plugin[0]}" "alpha"
}

# shellcheck disable=SC2154 # globals created by _test_runtime_reset
function testReadPluginsSkipsBlankLines() {
	_test_runtime_parse 'alpha

beta

'
	_bashy_assert_equal "${#bashy_array_plugin[@]}" 2
}

# shellcheck disable=SC2154 # globals created by _test_runtime_reset
function testReadPluginsSkipsWhitespaceOnlyLines() {
	_test_runtime_parse 'alpha

beta
'
	_bashy_assert_equal "${#bashy_array_plugin[@]}" 2
}

# shellcheck disable=SC2154 # globals created by _test_runtime_reset
function testReadPluginsLastEntryWins() {
	# ~/.bashy.list is read after bashy.list precisely so a user can override, which
	# only works if a later line replaces the earlier setting
	_test_runtime_parse 'alpha
-alpha
'
	_bashy_assert_equal "${bashy_assoc_enabled[alpha]}" 0
}

# shellcheck disable=SC2154 # globals created by _test_runtime_reset
function testReadPluginsEmptyFile() {
	_test_runtime_parse ''
	_bashy_assert_equal "${#bashy_array_plugin[@]}" 0
}

# shellcheck disable=SC2154 # globals created by _test_runtime_reset
function testReadPluginsNoTrailingNewline() {
	# a hand edited list may well not end in a newline, and "read" returns false on
	# the last line when it does not
	_test_runtime_parse 'alpha
beta'
	_bashy_assert_equal "${#bashy_array_plugin[@]}" 2
	_bashy_assert_equal "${bashy_array_plugin[1]}" "beta"
}

function testBashyListEntriesAllExist() {
	# every plugin named in the shipped list must have a file, otherwise the shell
	# reports FOUND_ERROR for it
	local missing=0
	local line plugin
    while read -r line
	do
		[[ "${line}" =~ ^#.* ]] && continue
		[[ "${line}" =~ ^[[:space:]]*$ ]] && continue
		plugin="${line#-}"
		if [[ ! -r "src/plugins/${plugin}.sh" ]]
		then
			echo "no plugin file for [${plugin}]"
			missing=1
		fi
	done < src/bashy.list
	_bashy_assert_equal "${missing}" 0
}
