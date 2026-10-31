# shellcheck disable=SC2329 # test doubles are invoked indirectly by plugin installers
source src/core/assert.sh
source src/core/pathutils.sh
source src/core/install.sh

function _test_cursor_load() {
	function register() { :; }
	function register_install() { :; }
	source src/plugins/ai_cursor.sh
	unset -f register register_install
}

function testCursorDesktopUsesNativeReleaseAsset() {
	_test_cursor_load
	function uname() { echo "aarch64"; }
	function _bashy_pathutils_is_in_path() { [ "$1" = "dpkg" ]; }
	function _bashy_apt_installed() { return 0; }
	function dpkg-query() { echo "1.2.2-100"; }
	function bashy_fetch_latest() {
		_bashy_assert_equal "$1" "https://cursor.com/api/download?platform=linux-arm64&releaseTrack=stable"
		local -n __out=$2
		__out='{"version":"1.2.3","debUrl":"https://downloads.cursor.com/cursor_1.2.3_arm64.deb"}'
	}
	function bashy_install_deb() { echo "deb $1 $2"; }
	local out
	out=$(_install_cursor_deb)
	_bashy_assert_equal "${out}" $'cursor 1.2.2 is installed, upgrading to 1.2.3\ndeb cursor https://downloads.cursor.com/cursor_1.2.3_arm64.deb'
	function dpkg-query() { echo "1.2.3-100"; }
	_bashy_assert_equal "$(_install_cursor_deb)" "cursor 1.2.3 is already installed (latest)"
	out=$(_install_cursor_deb --force)
	[[ "${out}" == *"reinstalling"* ]] || _bashy_assert_fail
	[[ "${out}" == *"deb cursor https://downloads.cursor.com/cursor_1.2.3_arm64.deb"* ]] || _bashy_assert_fail
}

function testCursorDesktopRejectsIncompleteMetadata() {
	_test_cursor_load
	function uname() { echo "x86_64"; }
	function _bashy_pathutils_is_in_path() { return 0; }
	function bashy_install_deb() { _bashy_assert_fail; }
	function bashy_fetch_latest() {
		local -n __out=$2
		__out="${response}"
	}
	local response
	for response in '{}' '{"debUrl":"https://downloads.cursor.com/cursor.deb"}' '{"version":"1.2.3"}'
	do
		_install_cursor_deb > /dev/null 2>&1 && _bashy_assert_fail
	done
	return 0
}

function testCursorUnsupportedArchitectureDoesNotDownload() {
	_test_cursor_load
	function uname() { echo "riscv64"; }
	function _bashy_pathutils_is_in_path() { return 0; }
	function bashy_fetch_latest() { _bashy_assert_fail; }
	_install_cursor_deb > /dev/null 2>&1 && _bashy_assert_fail
	_install_cursor_agent_tar > /dev/null 2>&1 && _bashy_assert_fail
	return 0
}

function testCursorCombinedInstallerForwardsFlagsAndFailures() {
	_test_cursor_load
	function _install_cursor_deb() { echo "desktop $1"; }
	function _install_cursor_agent_tar() { echo "agent $1"; }
	_bashy_assert_equal "$(_install_cursor --refresh)" $'using _install_cursor_deb\ndesktop --refresh\nusing _install_cursor_agent_tar\nagent --refresh'
	function _install_cursor_deb() { return 1; }
	function _install_cursor_agent_tar() { _bashy_assert_fail; }
	_install_cursor --force > /dev/null 2>&1 && _bashy_assert_fail
	return 0
}

function _test_cursor_agent_setup() {
	local -n __dir=$1
	__dir=$(mktemp --directory)
	_test_cursor_load
	mkdir -p "${__dir}/fixture/dist-package"
	cat > "${__dir}/fixture/dist-package/cursor-agent" <<'EOF'
#!/bin/bash
echo "2099.01.01-abcdef0"
EOF
	chmod +x "${__dir}/fixture/dist-package/cursor-agent"
	cp "${__dir}/fixture/dist-package/cursor-agent" "${__dir}/fixture/dist-package/node"
	echo "agent code" > "${__dir}/fixture/dist-package/index.js"
	tar czf "${__dir}/agent-cli-package.tar.gz" -C "${__dir}/fixture" dist-package
	function uname() { echo "x86_64"; }
	function bashy_fetch_latest() {
		_bashy_assert_equal "$1" "https://cursor.com/install"
		local -n __out=$2
		# shellcheck disable=SC2016 # literal vendor script, not shell to execute
		__out='DOWNLOAD_URL="https://downloads.cursor.com/lab/2099.01.01-abcdef0/${OS}/${ARCH}/agent-cli-package.tar.gz"
exit 99'
	}
	function bashy_download() {
		_bashy_assert_equal "$1" "https://downloads.cursor.com/lab/2099.01.01-abcdef0/linux/x64/agent-cli-package.tar.gz"
		local -n __out=$2
		__out="${HOME}/agent-cli-package.tar.gz"
	}
}

function testCursorAgentInstallsCompleteVersionedPackage() {
	local dir
	_test_cursor_agent_setup dir
	local HOME="${dir}"
	_install_cursor_agent_tar > /dev/null || _bashy_assert_fail
	local folder="${HOME}/.local/share/cursor-agent/versions/2099.01.01-abcdef0"
	_bashy_assert_equal "$(readlink "${HOME}/.local/bin/agent")" "${folder}/cursor-agent"
	_bashy_assert_equal "$(readlink "${HOME}/.local/bin/cursor-agent")" "${folder}/cursor-agent"
	_bashy_assert_equal "$(cat "${folder}/index.js")" "agent code"
	[ -x "${folder}/node" ] || _bashy_assert_fail
	_bashy_assert_equal "$("${HOME}/.local/bin/cursor-agent" --version)" "2099.01.01-abcdef0"
	function bashy_download() { _bashy_assert_fail; }
	_bashy_assert_equal "$(_install_cursor_agent_tar)" "cursor-agent 2099.01.01-abcdef0 is already installed (latest)"
	rm -rf "${dir}"
}

function testCursorAgentFailedReinstallPreservesWorkingVersion() {
	local dir
	_test_cursor_agent_setup dir
	local HOME="${dir}"
	_install_cursor_agent_tar > /dev/null || _bashy_assert_fail
	function bashy_install_extract() { return 1; }
	_install_cursor_agent_tar --force > /dev/null 2>&1 && _bashy_assert_fail
	_bashy_assert_equal "$("${HOME}/.local/bin/agent" --version)" "2099.01.01-abcdef0"
	local -a staged
	shopt -s nullglob
	staged=("${HOME}/.local/share/cursor-agent/versions/".tmp.*)
	_bashy_assert_equal "${#staged[@]}" "0"
	rm -rf "${dir}"
}

function testCursorAgentRejectsUnsafeOrMissingReleaseVersion() {
	_test_cursor_load
	function uname() { echo "x86_64"; }
	function bashy_download() { _bashy_assert_fail; }
	function bashy_fetch_latest() {
		local -n __out=$2
		__out="${response}"
	}
	local response
	# shellcheck disable=SC2016 # a release version must never be executed
	for response in '' 'DOWNLOAD_URL="https://downloads.cursor.com/lab/../linux/x64/agent-cli-package.tar.gz"' \
		'DOWNLOAD_URL="https://downloads.cursor.com/lab/$(touch unwanted)/linux/x64/agent-cli-package.tar.gz"'
	do
		_install_cursor_agent_tar > /dev/null 2>&1 && _bashy_assert_fail
	done
	return 0
}

function testCursorAgentUninstallPreservesUnrelatedAgentAndSettings() {
	local dir
	_test_cursor_agent_setup dir
	local HOME="${dir}"
	_install_cursor_agent_tar > /dev/null || _bashy_assert_fail
	mkdir -p "${HOME}/.cursor"
	echo "settings" > "${HOME}/.cursor/settings"
	ln --symbolic --force "${HOME}/unrelated-agent" "${HOME}/.local/bin/agent"
	_uninstall_cursor_agent_tar > /dev/null
	[ ! -L "${HOME}/.local/bin/cursor-agent" ] || _bashy_assert_fail
	[ ! -d "${HOME}/.local/share/cursor-agent" ] || _bashy_assert_fail
	_bashy_assert_equal "$(readlink "${HOME}/.local/bin/agent")" "${HOME}/unrelated-agent"
	_bashy_assert_equal "$(cat "${HOME}/.cursor/settings")" "settings"
	rm -rf "${dir}"
}
