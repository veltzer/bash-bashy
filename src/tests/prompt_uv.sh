source src/core/assert.sh
source src/core/misc.sh
source src/core/hooks.sh
source src/core/log.sh
source src/core/var.sh
source src/core/pathutils.sh
source src/core/python.sh
source src/core/check.sh
source src/plugins/prompt_uv.sh

# Build a throwaway uv project and a fake uv whose 'sync' just creates the
# venv. The fake is reachable only through _BASHY_UV_BIN, never through the
# PATH - which is exactly the situation after the plugin holds the env that
# uv itself came from, the case that used to poison '.uv.sync.errors' with
# "uv: command not found" after a 'git clean' removed '.venv'.
function _test_prompt_uv_setup() {
	_test_prompt_uv_dir=$(mktemp -d)
	echo '[project]' > "${_test_prompt_uv_dir}/pyproject.toml"
	_BASHY_UV_BIN="${_test_prompt_uv_dir}/fake_uv"
	cat > "${_BASHY_UV_BIN}" <<'EOF'
#!/bin/bash
mkdir -p .venv/bin
touch .venv/bin/activate
EOF
	chmod +x "${_BASHY_UV_BIN}"
	_BASHY_UV_ACTIVE=""
	_BASHY_UV_HELD=""
	cd "${_test_prompt_uv_dir}" || exit 1
}

function _test_prompt_uv_teardown() {
	cd / || exit 1
	rm -rf "${_test_prompt_uv_dir}"
}

function testPromptUvFindsRootAbove() {
	_test_prompt_uv_setup
	mkdir -p deep/er
	cd deep/er || _bashy_assert_fail
	local root=""
	_prompt_uv_find_root root || _bashy_assert_fail
	# walking up is done in the shell now, dirname(1) used to be four forks a prompt
	_bashy_assert_equal "${root}" "${_test_prompt_uv_dir}"
	_test_prompt_uv_teardown
}

function testPromptUvFindsNoRootAtTop() {
	local dir
	dir=$(mktemp -d)
	cd "${dir}" || _bashy_assert_fail
	local root=""
	if [ ! -e /pyproject.toml ] && [ ! -e /tmp/pyproject.toml ] && _prompt_uv_find_root root
	then
		_bashy_assert_fail
	fi
	cd / || _bashy_assert_fail
	rm -rf "${dir}"
	return 0
}

function testPromptUvRecreatesDeletedVenv() {
	_test_prompt_uv_setup
	prompt_uv
	_bashy_assert_equal "${_BASHY_UV_ACTIVE}" "${_test_prompt_uv_dir}/.venv"
	if [ ! -f .venv/pyproject.toml.checksum ]
	then
		_bashy_assert_fail
	fi
	# a 'git clean' takes the venv, checksum file included
	rm -rf .venv
	prompt_uv
	if [ ! -d .venv/bin ]
	then
		_bashy_assert_fail
	fi
	if [ ! -f .venv/pyproject.toml.checksum ]
	then
		_bashy_assert_fail
	fi
	if [ -f .uv.sync.errors ]
	then
		_bashy_assert_fail
	fi
	_test_prompt_uv_teardown
}

function testPromptUvStaleErrorFileDoesNotBlockCreation() {
	_test_prompt_uv_setup
	# a failure recorded against a venv that no longer exists must not
	# stop the venv from being created
	echo "old failure" > .uv.sync.errors
	prompt_uv
	if [ ! -d .venv/bin ]
	then
		_bashy_assert_fail
	fi
	if [ -f .uv.sync.errors ]
	then
		_bashy_assert_fail
	fi
	_test_prompt_uv_teardown
}

function testPromptUvErrorFileStillBlocksWhenVenvExists() {
	_test_prompt_uv_setup
	prompt_uv
	# with the venv in place an error file must keep blocking syncs
	echo 'changed' >> pyproject.toml
	echo "boom" > .uv.sync.errors
	prompt_uv
	_bashy_assert_equal "$(cat .uv.sync.errors)" "boom"
	_test_prompt_uv_teardown
}
