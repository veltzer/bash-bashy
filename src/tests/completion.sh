source src/core/assert.sh
source src/core/log.sh
source src/core/completion.sh

# a stand in for a real tool, so these tests do not depend on minikube or gh being
# installed and can control exactly when the "tool" changes
function _test_completion_tool() {
	local dir=$1
	local text=$2
	mkdir -p "${dir}/bin"
	printf '#!/bin/bash\necho "%s"\n' "${text}" > "${dir}/bin/faketool"
	chmod +x "${dir}/bin/faketool"
}

function testCompletionCachesAndReuses() {
	local dir
	dir=$(mktemp --directory)
	_test_completion_tool "${dir}" "complete -W v1 faketool"
	export BASHY_COMPLETION_CACHE="${dir}/cache"
	PATH="${dir}/bin:${PATH}" bashy_completion faketool faketool > /dev/null || _bashy_assert_fail
	# the cache file has to exist afterwards, that is the whole point
	if [ ! -s "${dir}/cache/faketool.bash" ]
	then
		rm -rf "${dir}"
		_bashy_assert_fail
	fi
	_bashy_assert_equal "$(cat "${dir}/cache/faketool.bash")" "complete -W v1 faketool"
	rm -rf "${dir}"
}

function testCompletionServesFromCache() {
	local dir
	dir=$(mktemp --directory)
	_test_completion_tool "${dir}" "complete -W v1 faketool"
	export BASHY_COMPLETION_CACHE="${dir}/cache"
	PATH="${dir}/bin:${PATH}" bashy_completion faketool faketool > /dev/null
	# break the tool but give it back the mtime the stamp remembers, so a second
	# call that still succeeds proves the answer came from the cache
	printf '#!/bin/bash\nexit 1\n' > "${dir}/bin/faketool"
	touch -r "${dir}/cache/faketool.bash.stamp" "${dir}/bin/faketool"
	PATH="${dir}/bin:${PATH}" bashy_completion faketool faketool > /dev/null || _bashy_assert_fail
	_bashy_assert_equal "$(cat "${dir}/cache/faketool.bash")" "complete -W v1 faketool"
	rm -rf "${dir}"
}

function testCompletionInvalidatesWhenToolIsOlder() {
	local dir
	dir=$(mktemp --directory)
	_test_completion_tool "${dir}" "complete -W v1 faketool"
	export BASHY_COMPLETION_CACHE="${dir}/cache"
	PATH="${dir}/bin:${PATH}" bashy_completion faketool faketool > /dev/null
	# a package manager can install a binary carrying its build date, older than
	# the stamp. A "newer than" test alone would keep serving v1 for it.
	_test_completion_tool "${dir}" "complete -W v2 faketool"
	touch -d '2000-01-01' "${dir}/bin/faketool"
	PATH="${dir}/bin:${PATH}" bashy_completion faketool faketool > /dev/null
	_bashy_assert_equal "$(cat "${dir}/cache/faketool.bash")" "complete -W v2 faketool"
	rm -rf "${dir}"
}

function testCompletionInvalidatesWhenToolChanges() {
	local dir
	dir=$(mktemp --directory)
	_test_completion_tool "${dir}" "complete -W v1 faketool"
	export BASHY_COMPLETION_CACHE="${dir}/cache"
	PATH="${dir}/bin:${PATH}" bashy_completion faketool faketool > /dev/null
	# rewriting immediately means the mtime moves by less than a second, which is
	# exactly the case a whole second stamp used to miss
	_test_completion_tool "${dir}" "complete -W v2 faketool"
	PATH="${dir}/bin:${PATH}" bashy_completion faketool faketool > /dev/null
	_bashy_assert_equal "$(cat "${dir}/cache/faketool.bash")" "complete -W v2 faketool"
	rm -rf "${dir}"
}

function testCompletionFindsBinaryBehindFunction() {
	local dir
	dir=$(mktemp --directory)
	_test_completion_tool "${dir}" "complete -W v1 faketool"
	export BASHY_COMPLETION_CACHE="${dir}/cache"
	# a plugin may wrap the tool in a function of the same name. The cache has to
	# key on the binary behind it, or the stamp never matches and every shell
	# regenerates.
	function faketool() { echo "the function, not the binary"; }
	# a direct call first, so the function has a visible call site
	_bashy_assert_equal "$(faketool)" "the function, not the binary"
	PATH="${dir}/bin:${PATH}" bashy_completion faketool faketool > /dev/null || _bashy_assert_fail
	_bashy_assert_equal "$(cat "${dir}/cache/faketool.bash")" "complete -W v1 faketool"
	if [ "${dir}/bin/faketool" -nt "${dir}/cache/faketool.bash.stamp" ] \
		|| [ "${dir}/bin/faketool" -ot "${dir}/cache/faketool.bash.stamp" ]
	then
		_bashy_assert_fail
	fi
	unset -f faketool
	rm -rf "${dir}"
}

function testCompletionMissingToolFails() {
	local dir
	dir=$(mktemp --directory)
	export BASHY_COMPLETION_CACHE="${dir}/cache"
	bashy_completion no_such_tool_anywhere no_such_tool_anywhere > /dev/null 2>&1 \
		&& { rm -rf "${dir}"; _bashy_assert_fail; }
	rm -rf "${dir}"
	return 0
}

function testCompletionFailingCommandLeavesNoCache() {
	local dir
	dir=$(mktemp --directory)
	mkdir -p "${dir}/bin"
	# a tool that exists but produces nothing and fails
	printf '#!/bin/bash\nexit 1\n' > "${dir}/bin/faketool"
	chmod +x "${dir}/bin/faketool"
	export BASHY_COMPLETION_CACHE="${dir}/cache"
	PATH="${dir}/bin:${PATH}" bashy_completion faketool faketool > /dev/null 2>&1 \
		&& { rm -rf "${dir}"; _bashy_assert_fail; }
	# a failed run must not leave a cache file, or the failure becomes permanent
	if [ -e "${dir}/cache/faketool.bash" ]
	then
		rm -rf "${dir}"
		_bashy_assert_fail
	fi
	rm -rf "${dir}"
	return 0
}

function testCompletionCleanRemovesCache() {
	local dir
	dir=$(mktemp --directory)
	_test_completion_tool "${dir}" "complete -W v1 faketool"
	export BASHY_COMPLETION_CACHE="${dir}/cache"
	PATH="${dir}/bin:${PATH}" bashy_completion faketool faketool > /dev/null
	bashy_completion_clean > /dev/null
	if [ -d "${dir}/cache" ]
	then
		rm -rf "${dir}"
		_bashy_assert_fail
	fi
	rm -rf "${dir}"
}
