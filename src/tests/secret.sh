source src/core/assert.sh
source src/core/secret.sh

# a stand in for pass(1) that knows exactly one entry
function _test_secret_pass() {
	local -n __dir=$1
	__dir=$(mktemp --directory)
	mkdir -p "${__dir}/bin"
	cat > "${__dir}/bin/pass" <<'PASS'
#!/bin/bash
if [ "$1" = "show" ] && [ "$2" = "keys/thing" ]
then
	echo "s3cret"
	exit 0
fi
exit 1
PASS
	chmod +x "${__dir}/bin/pass"
}

function testWithSecretSetsVariableForCommand() {
	local dir
	_test_secret_pass dir
	local out
	# shellcheck disable=SC2016 # the expansion is meant for the child shell
	out=$(PATH="${dir}/bin:${PATH}" bashy_with_secret THING_TOKEN "keys/thing" sh -c 'echo "[${THING_TOKEN}]"')
	_bashy_assert_equal "${out}" "[s3cret]"
	rm -rf "${dir}"
}

function testWithSecretDoesNotLeakIntoShell() {
	local dir
	_test_secret_pass dir
	unset THING_TOKEN
	PATH="${dir}/bin:${PATH}" bashy_with_secret THING_TOKEN "keys/thing" true
	# the variable is for the command only, never for the shell that ran it
	if [ -n "${THING_TOKEN+x}" ]
	then
		_bashy_assert_fail
	fi
	rm -rf "${dir}"
}

function testWithSecretMissingEntryRunsNothing() {
	local dir
	_test_secret_pass dir
	local marker="${dir}/ran"
	if PATH="${dir}/bin:${PATH}" bashy_with_secret THING_TOKEN "keys/absent" touch "${marker}" 2>/dev/null
	then
		_bashy_assert_fail
	fi
	if [ -e "${marker}" ]
	then
		_bashy_assert_fail
	fi
	rm -rf "${dir}"
	return 0
}

function testWithSecretPassesArguments() {
	local dir
	_test_secret_pass dir
	local out
	out=$(PATH="${dir}/bin:${PATH}" bashy_with_secret THING_TOKEN "keys/thing" printf '%s-' one "two words")
	_bashy_assert_equal "${out}" "one-two words-"
	rm -rf "${dir}"
}
