source src/core/assert.sh
source src/core/log.sh
source src/core/download.sh

# these tests must not touch the network, so they drive the pieces that do not
# need it and stub the validator lookup where a cache decision is being checked

function testVerifySha256LiteralDigest() {
	local dir
	dir=$(mktemp --directory)
	echo "hello bashy" > "${dir}/file"
	local sum
	sum=$(sha256sum "${dir}/file" | awk '{print $1}')
	bashy_verify_sha256 "${dir}/file" "${sum}" > /dev/null || _bashy_assert_fail
	rm -rf "${dir}"
}

function testVerifySha256RejectsMismatch() {
	local dir
	dir=$(mktemp --directory)
	echo "hello bashy" > "${dir}/file"
	local zeros="0000000000000000000000000000000000000000000000000000000000000000"
	bashy_verify_sha256 "${dir}/file" "${zeros}" > /dev/null 2>&1 && _bashy_assert_fail
	rm -rf "${dir}"
}

function testVerifySha256RejectsMissingFile() {
	bashy_verify_sha256 "/nonexistent/file" \
		"0000000000000000000000000000000000000000000000000000000000000000" \
		> /dev/null 2>&1 && _bashy_assert_fail
	return 0
}

function testVerifySha256ChecksumsFile() {
	local dir
	dir=$(mktemp --directory)
	echo "hello bashy" > "${dir}/tool_linux.tar.gz"
	echo "other" > "${dir}/tool_darwin.tar.gz"
	# a checksums.txt listing several assets, as gh and lazygit publish
	(cd "${dir}" && sha256sum tool_linux.tar.gz tool_darwin.tar.gz > checksums.txt)
	bashy_verify_sha256 "${dir}/tool_linux.tar.gz" "file://${dir}/checksums.txt" > /dev/null \
		|| _bashy_assert_fail
	rm -rf "${dir}"
}

function testVerifySha256BareDigestFile() {
	local dir
	dir=$(mktemp --directory)
	echo "hello bashy" > "${dir}/tool"
	# minikube and friends publish just the digest, with no filename column
	sha256sum "${dir}/tool" | awk '{print $1}' > "${dir}/tool.sha256"
	bashy_verify_sha256 "${dir}/tool" "file://${dir}/tool.sha256" > /dev/null \
		|| _bashy_assert_fail
	rm -rf "${dir}"
}

function testVerifySha256PathAndBinaryMarker() {
	local dir
	dir=$(mktemp --directory)
	echo "hello bashy" > "${dir}/rustup-init"
	# rustup publishes "<digest> *./rustup-init": a binary marker and a path, not a
	# bare filename, and both have to be stripped before the name can be matched
	local sum
	sum=$(sha256sum "${dir}/rustup-init" | awk '{print $1}')
	printf '%s *./rustup-init\n' "${sum}" > "${dir}/sums.txt"
	bashy_verify_sha256 "${dir}/rustup-init" "file://${dir}/sums.txt" > /dev/null \
		|| _bashy_assert_fail
	rm -rf "${dir}"
}

function testVerifySha256FileNotListed() {
	local dir
	dir=$(mktemp --directory)
	echo "hello bashy" > "${dir}/tool_linux.tar.gz"
	echo "unrelated" > "${dir}/other.tar.gz"
	(cd "${dir}" && sha256sum other.tar.gz > checksums.txt)
	bashy_verify_sha256 "${dir}/tool_linux.tar.gz" "file://${dir}/checksums.txt" \
		> /dev/null 2>&1 && _bashy_assert_fail
	rm -rf "${dir}"
}

function testDownloadReusesCacheWhenValidatorMatches() {
	local dir
	dir=$(mktemp --directory)
	export BASHY_DOWNLOAD_CACHE="${dir}"
	echo "cached bytes" > "${dir}/thing.tar.gz"
	echo 'etag: "same"' > "${dir}/thing.tar.gz.etag"
	# pretend the origin still reports the very same validator
	function _bashy_download_validator() { echo 'etag: "same"'; }
	local out=""
	bashy_download "https://example.invalid/thing.tar.gz" out || _bashy_assert_fail
	_bashy_assert_equal "$(cat "${out}")" "cached bytes"
	unset -f _bashy_download_validator
	rm -rf "${dir}"
}

function testDownloadRefetchesWhenValidatorChanged() {
	local dir
	dir=$(mktemp --directory)
	export BASHY_DOWNLOAD_CACHE="${dir}"
	# this is the buck2 bug: a rolling asset keeps one filename forever, so the
	# name alone can never say whether the cached copy is still current
	echo "stale build" > "${dir}/rolling.zst"
	echo 'etag: "old"' > "${dir}/rolling.zst.etag"
	function _bashy_download_validator() { echo 'etag: "new"'; }
	local out=""
	# the refetch itself must fail against an unreachable host, proving that a
	# changed validator does not serve the stale copy
	bashy_download "https://example.invalid/rolling.zst" out > /dev/null 2>&1 \
		&& _bashy_assert_fail
	unset -f _bashy_download_validator
	rm -rf "${dir}"
}

function testDownloadKeepsCacheWhenOffline() {
	local dir
	dir=$(mktemp --directory)
	export BASHY_DOWNLOAD_CACHE="${dir}"
	echo "cached bytes" > "${dir}/thing.tar.gz"
	echo 'etag: "old"' > "${dir}/thing.tar.gz.etag"
	# no validator at all means we could not reach the origin, the cached copy
	# is then better than failing the install outright
	function _bashy_download_validator() { echo ""; }
	local out=""
	bashy_download "https://example.invalid/thing.tar.gz" out || _bashy_assert_fail
	_bashy_assert_equal "$(cat "${out}")" "cached bytes"
	unset -f _bashy_download_validator
	rm -rf "${dir}"
}

function testDownloadFailureReportsCurlExit() {
	local dir
	dir=$(mktemp --directory)
	export BASHY_DOWNLOAD_CACHE="${dir}/cache"
	local out="" err
	# a missing local file fails curl without the network (exit 37); the message
	# has to carry curl's exit code, and no partial file may stay behind
	err=$(bashy_download "file://${dir}/missing.tar.gz" out 2>&1 >/dev/null) && _bashy_assert_fail
	[[ "${err}" == *"curl exit 37, 0 bytes received"* ]] || _bashy_assert_fail
	[ -e "${dir}/cache/missing.tar.gz.part" ] && _bashy_assert_fail
	rm -rf "${dir}"
}
