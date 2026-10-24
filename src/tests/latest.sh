source src/core/assert.sh
source src/core/log.sh
source src/core/latest.sh
source src/core/install.sh

# these tests must not touch the network: curl is replaced by a function that
# answers with a counter, so a test can tell a fetch from a cache hit. The fetch
# runs in a command substitution, so the counter lives in a file.

function _latest_test_setup() {
	BASHY_LATEST_CACHE=$(mktemp --directory)
	_latest_test_counter=$(mktemp)
	echo 0 > "${_latest_test_counter}"
	function curl() {
		local count
		count=$(( $(< "${_latest_test_counter}") + 1 ))
		echo "${count}" > "${_latest_test_counter}"
		[ "${_latest_test_fail:-0}" -eq 1 ] && return 22
		echo "answer ${count}"
	}
}

# _latest_test_fetches
# How many times curl was called since the setup.
function _latest_test_fetches() {
	cat "${_latest_test_counter}"
}

function _latest_test_teardown() {
	unset -f curl
	rm -rf "${BASHY_LATEST_CACHE}" "${_latest_test_counter}"
	unset _latest_test_fail
	bashy_install_args
}

function testLatestCachesWithinTtl() {
	_latest_test_setup
	bashy_install_args
	local out
	bashy_fetch_latest "https://example.com/latest" out || _bashy_assert_fail
	_bashy_assert_equal "${out}" "answer 1"
	# a second ask within the ttl is answered from the cache, without a fetch
	bashy_fetch_latest "https://example.com/latest" out || _bashy_assert_fail
	_bashy_assert_equal "${out}" "answer 1"
	_bashy_assert_equal "$(_latest_test_fetches)" "1"
	# the echoing form gives the same answer
	_bashy_assert_equal "$(bashy_fetch_latest "https://example.com/latest")" "answer 1"
	# another url is another entry
	bashy_fetch_latest "https://example.com/other" out || _bashy_assert_fail
	_bashy_assert_equal "${out}" "answer 2"
	_latest_test_teardown
	return 0
}

function testLatestExpiresAfterTtl() {
	_latest_test_setup
	bashy_install_args
	local out
	bashy_fetch_latest "https://example.com/latest" out || _bashy_assert_fail
	# age the entry past the ttl
	local file
	_bashy_latest_file "https://example.com/latest" file
	touch --date="@$(( $(date +%s) - BASHY_LATEST_TTL - 1 ))" "${file}"
	bashy_fetch_latest "https://example.com/latest" out || _bashy_assert_fail
	_bashy_assert_equal "${out}" "answer 2"
	_latest_test_teardown
	return 0
}

function testLatestRefreshAndForceSkipCache() {
	_latest_test_setup
	local out
	bashy_install_args
	bashy_fetch_latest "https://example.com/latest" out || _bashy_assert_fail
	bashy_install_args --refresh || _bashy_assert_fail
	bashy_fetch_latest "https://example.com/latest" out || _bashy_assert_fail
	_bashy_assert_equal "${out}" "answer 2"
	# --force implies --refresh
	bashy_install_args --force || _bashy_assert_fail
	_bashy_assert_equal "${BASHY_INSTALL_REFRESH}" "1"
	bashy_fetch_latest "https://example.com/latest" out || _bashy_assert_fail
	_bashy_assert_equal "${out}" "answer 3"
	# the refreshed answer is what a plain run gets next
	bashy_install_args
	bashy_fetch_latest "https://example.com/latest" out || _bashy_assert_fail
	_bashy_assert_equal "${out}" "answer 3"
	_bashy_assert_equal "$(_latest_test_fetches)" "3"
	_latest_test_teardown
	return 0
}

function testLatestFailureIsNotCached() {
	_latest_test_setup
	bashy_install_args
	local out
	_latest_test_fail=1
	bashy_fetch_latest "https://example.com/latest" out 2> /dev/null && _bashy_assert_fail
	_latest_test_fail=0
	bashy_fetch_latest "https://example.com/latest" out || _bashy_assert_fail
	_bashy_assert_equal "${out}" "answer 2"
	_latest_test_teardown
	return 0
}

function testLatestListAndClean() {
	_latest_test_setup
	bashy_install_args
	local out
	bashy_fetch_latest "https://example.com/latest" out || _bashy_assert_fail
	[[ "$(bashy_latest_list)" == *"https://example.com/latest" ]] || _bashy_assert_fail
	bashy_latest_clean > /dev/null
	[ -d "${BASHY_LATEST_CACHE}" ] && _bashy_assert_fail
	_latest_test_teardown
	return 0
}
