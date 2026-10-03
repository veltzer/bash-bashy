source src/core/assert.sh
source src/core/install.sh

function testInstallCheckNotInstalled() {
	local out
	out=$(bashy_install_check "gh" "" "2.96.0")
	_bashy_assert_equal "${out}" "Installing gh 2.96.0"
	# an empty installed version means there is work to do
	bashy_install_check "gh" "" "2.96.0" > /dev/null && _bashy_assert_fail
	return 0
}

function testInstallCheckUpToDate() {
	local out
	bashy_install_args
	out=$(bashy_install_check "gh" "2.96.0" "2.96.0")
	_bashy_assert_equal "${out}" "gh 2.96.0 is already installed (latest)"
	# up to date returns 0 so the caller returns early
	bashy_install_check "gh" "2.96.0" "2.96.0" > /dev/null || _bashy_assert_fail
}

function testInstallCheckUpToDateForced() {
	# --force turns the up to date case into a reinstall: the line says so and the
	# caller is told to go on
	local out
	bashy_install_args --force
	out=$(bashy_install_check "gh" "2.96.0" "2.96.0")
	_bashy_assert_equal "${out}" "gh 2.96.0 is already installed (latest), reinstalling"
	bashy_install_check "gh" "2.96.0" "2.96.0" > /dev/null && _bashy_assert_fail
	# the other two cases read the same with or without the flag
	_bashy_assert_equal "$(bashy_install_check "gh" "" "2.96.0")" "Installing gh 2.96.0"
	_bashy_assert_equal "$(bashy_install_check "gh" "2.95.0" "2.96.0")" "gh 2.95.0 is installed, upgrading to 2.96.0"
	bashy_install_args
	return 0
}

function testInstallArgsParsesForce() {
	# no arguments means a plain install, whatever the previous installer asked for
	bashy_install_args --force || _bashy_assert_fail
	bashy_install_forced || _bashy_assert_fail
	bashy_install_args || _bashy_assert_fail
	bashy_install_forced && _bashy_assert_fail
	_bashy_assert_equal "${BASHY_INSTALL_FORCE}" "0"
	return 0
}

function testInstallArgsRejectsUnknown() {
	# a misspelt flag must fail loudly rather than run a plain install, and must
	# name the installer that was called
	function _install_thing() { bashy_install_args "$@" || return; echo "installed"; }
	local out err
	out=$(_install_thing --froce 2>/dev/null) && _bashy_assert_fail
	_bashy_assert_equal "${out}" ""
	err=$(_install_thing --froce 2>&1 > /dev/null)
	_bashy_assert_equal "${err}" "_install_thing: unknown argument [--froce], the only option is --force"
	_bashy_assert_equal "$(_install_thing --force)" "installed"
	unset -f _install_thing
	bashy_install_args
	return 0
}

function testInstallCheckUpgrade() {
	local out
	out=$(bashy_install_check "gh" "2.95.0" "2.96.0")
	_bashy_assert_equal "${out}" "gh 2.95.0 is installed, upgrading to 2.96.0"
	bashy_install_check "gh" "2.95.0" "2.96.0" > /dev/null && _bashy_assert_fail
	return 0
}

function testInstallCheckNoLatestVersion() {
	# a failed version lookup must not silently look like a fresh install
	local err
	err=$(bashy_install_check "packer" "1.16.0" "" 2>&1 > /dev/null)
	_bashy_assert_equal "${err}" "packer: could not determine the latest version"
	bashy_install_check "packer" "1.16.0" "" 2>/dev/null && _bashy_assert_fail
	return 0
}

function testInstallDownloadFormat() {
	local out
	out=$(bashy_install_download "https://example.com/x.tar.gz")
	_bashy_assert_equal "${out}" "download_file is [https://example.com/x.tar.gz]"
}

function testGithubVersionStripsPrefix() {
	local json='{"tag_name": "v1.2.3"}'
	_bashy_assert_equal "$(bashy_github_version "${json}")" "1.2.3"
	# some projects tag with something else entirely
	local audacity='{"tag_name": "Audacity-3.7.8"}'
	_bashy_assert_equal "$(bashy_github_version "${audacity}" "Audacity-")" "3.7.8"
	# bazel tags without any prefix, an empty prefix must leave it alone
	local bazel='{"tag_name": "9.2.0"}'
	_bashy_assert_equal "$(bashy_github_version "${bazel}" "")" "9.2.0"
	# biome tags with an npm package name, so the prefix holds a slash and
	# a dot - both must be taken literally
	local biome='{"tag_name": "@biomejs/biome@2.5.15"}'
	_bashy_assert_equal "$(bashy_github_version "${biome}" "@biomejs/biome@")" "2.5.15"
	# a prefix that is not there must leave the tag alone, not strip part of it
	_bashy_assert_equal "$(bashy_github_version "${json}" "x")" "v1.2.3"
}

function _test_install_assets_json() {
	echo '{"assets": [
		{"browser_download_url": "https://e.com/tool_1.0_linux-amd64.tar.gz"},
		{"browser_download_url": "https://e.com/tool_withdeploy_1.0_linux-amd64.tar.gz"},
		{"browser_download_url": "https://e.com/tool_1.0_darwin-amd64.tar.gz"}
	]}'
}

function testGithubAssetUnique() {
	local json
	json=$(_test_install_assets_json)
	local url
	url=$(bashy_github_asset "${json}" "tool_[0-9][^/]*_linux-amd64\\.tar\\.gz$")
	_bashy_assert_equal "${url}" "https://e.com/tool_1.0_linux-amd64.tar.gz"
}

function testGithubAssetAmbiguousFails() {
	local json
	json=$(_test_install_assets_json)
	# this is the hugo bug: a loose pattern matched two assets and returned both
	bashy_github_asset "${json}" "linux-amd64" > /dev/null 2>&1 && _bashy_assert_fail
	return 0
}

function testGithubAssetNoMatchFails() {
	local json
	json=$(_test_install_assets_json)
	bashy_github_asset "${json}" "windows" > /dev/null 2>&1 && _bashy_assert_fail
	return 0
}

function testInstallExtractStampsMtime() {
	local dir
	dir=$(mktemp --directory)
	mkdir -p "${dir}/src"
	echo hello > "${dir}/src/thing"
	# an archive member with an mtime far in the past
	touch --date="2000-01-01" "${dir}/src/thing"
	tar cf "${dir}/a.tar" -C "${dir}/src" thing
	bashy_install_extract "${dir}/a.tar" "${dir}"
	local year
	year=$(date --reference="${dir}/thing" +%Y)
	_bashy_assert_equal "${year}" "$(date +%Y)"
	rm -rf "${dir}"
}

function testUninstallBinaryReports() {
	local dir
	dir=$(mktemp --directory)
	local out
	# nothing there yet
	out=$(bashy_uninstall_binary "thing" "${dir}/thing")
	_bashy_assert_equal "${out}" "no thing detected"
	# and once it is
	touch "${dir}/thing"
	out=$(bashy_uninstall_binary "thing" "${dir}/thing")
	_bashy_assert_equal "${out}" "removing ${dir}/thing"
	[ -f "${dir}/thing" ] && _bashy_assert_fail
	rm -rf "${dir}"
	return 0
}

function testUninstallDirectoryReports() {
	local dir
	dir=$(mktemp --directory)
	local out
	out=$(bashy_uninstall_directory "thing" "${dir}/tree")
	_bashy_assert_equal "${out}" "no thing detected"
	mkdir -p "${dir}/tree"
	out=$(bashy_uninstall_directory "thing" "${dir}/tree")
	_bashy_assert_equal "${out}" "removing ${dir}/tree"
	[ -d "${dir}/tree" ] && _bashy_assert_fail
	rm -rf "${dir}"
	return 0
}

function testInstallMarkerRoundTrip() {
	local dir
	dir=$(mktemp --directory)
	local marker
	marker=$(bashy_install_marker "${dir}" "thing")
	_bashy_assert_equal "${marker}" "${dir}/.thing_version"
	# writing one and reading it back needs the executable to be there too
	bashy_install_marker "${dir}" "thing" "1.2.3" > /dev/null
	_bashy_assert_equal "$(cat "${marker}")" "1.2.3"
	# a marker with no executable next to it must not read as installed
	_bashy_assert_equal "$(bashy_install_marker_version "${dir}" "thing" "${dir}/thing")" ""
	touch "${dir}/thing"
	chmod +x "${dir}/thing"
	_bashy_assert_equal "$(bashy_install_marker_version "${dir}" "thing" "${dir}/thing")" "1.2.3"
	rm -rf "${dir}"
}

function testInstallExtractZipStripsNothing() {
	# the zip branch has to unpack a named member just like the tar one does
	local dir
	dir=$(mktemp --directory)
	mkdir -p "${dir}/src"
	echo hello > "${dir}/src/thing"
	(cd "${dir}/src" && zip --quiet "${dir}/a.zip" thing)
	bashy_install_extract "${dir}/a.zip" "${dir}" thing
	_bashy_assert_equal "$(cat "${dir}/thing")" "hello"
	rm -rf "${dir}"
}

function testInstallAptSkipsInstalledPackages() {
	# dpkg is installed on any machine that has dpkg-query, so nothing is missing
	# and apt must not be touched at all: no index refresh, no install, no sudo
	function sudo() { echo "sudo must not run for an installed package [$*]" >&2; return 1; }
	local out
	out=$(bashy_install_apt "dpkg tools" "dpkg") || _bashy_assert_fail
	_bashy_assert_equal "${out}" "dpkg tools is already installed via apt [dpkg]"
	unset -f sudo
}

function testInstallAptReinstallsWhenForced() {
	local IFS=' '
	# every package is installed, which is normally a no-op, but --force sends
	# the list back to apt with --reinstall
	local calls=""
	function sudo() { calls="${calls}${*}\n"; return 0; }
	bashy_install_args --force
	local out
	out=$(bashy_install_apt "dpkg tools" "dpkg"; echo "${calls}")
	[[ "${out}" == *"Reinstalling dpkg tools via apt [dpkg]"* ]] || _bashy_assert_fail
	[[ "${out}" == *"apt-get install --reinstall --assume-yes dpkg"* ]] || _bashy_assert_fail
	unset -f sudo
	bashy_install_args
	return 0
}

function testInstallAptInstallsMissingPackages() {
	# the runner sets IFS to a newline, which would change how "$*" joins below
	local IFS=' '
	# one missing package is enough for the whole list to go to apt
	local calls=""
	function sudo() { calls="${calls}${*}\n"; return 0; }
	local out
	out=$(bashy_install_apt "nothing" "dpkg" "bashy-no-such-package-$$"; echo "${calls}")
	[[ "${out}" == *"Installing nothing via apt [dpkg bashy-no-such-package-$$]"* ]] || _bashy_assert_fail
	[[ "${out}" == *"apt-get update"* ]] || _bashy_assert_fail
	[[ "${out}" == *"apt-get install --assume-yes dpkg bashy-no-such-package-$$"* ]] || _bashy_assert_fail
	unset -f sudo
	return 0
}
