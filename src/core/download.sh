# Download cache for bashy plugins.
#
# Plugins used to download archives into /tmp and delete them right after
# extraction. This module gives them a persistent, content-addressed cache so
# that re-installing the same version skips the network entirely.
#
# Usage from a plugin:
#
#	local archive
#	bashy_download "${url}" archive || return 1
#	tar xf "${archive}" -C "${folder}" something
#
# The cached file is left in place on purpose - that is the whole point of the
# cache. Plugins should NOT 'rm' the path that bashy_download returns.
#
# When the project publishes checksums, verify before installing:
#
#	bashy_verify_sha256 "${archive}" "${checksums_url}" || return 1

# location of the cache, honoring XDG_CACHE_HOME, overridable via BASHY_DOWNLOAD_CACHE
if [ -z "${BASHY_DOWNLOAD_CACHE+x}" ]
then
	export BASHY_DOWNLOAD_CACHE="${XDG_CACHE_HOME:-${HOME}/.cache}/bashy/downloads"
fi

# _bashy_download_validator <url>
# Echo the origin's cache validator (etag, or last-modified when there is no etag).
# Echoes nothing when the origin serves neither or cannot be reached.
function _bashy_download_validator() {
	curl --fail --silent --head --location "$1" 2>/dev/null \
		| awk 'BEGIN{IGNORECASE=1}
			/^etag:/{sub(/\r$/,""); tag=$0}
			/^last-modified:/{sub(/\r$/,""); if(mod=="") mod=$0}
			END{print (tag!="" ? tag : mod)}'
}

# _bashy_download_return <path> [out_var]
# Hand <path> back to the caller, by name when out_var is given, otherwise on stdout.
function _bashy_download_return() {
	if [ -n "${2:-}" ]
	then
		local -n __out=$2
		__out="$1"
	else
		echo "$1"
	fi
}

# bashy_download <url> [out_var]
# Ensure <url> is present in the download cache and return its local path.
# If out_var is given the path is assigned to it, otherwise it is echoed.
# A cached file is reused only when the origin still reports the same validator,
# so rolling "latest" assets are refetched when they change upstream.
# Returns 0 on success, 1 on failure.
function bashy_download() {
	local url=$1
	local basename="${url##*/}"
	if [ -z "${basename}" ]
	then
		echo "bashy_download: cannot derive a filename from url [${url}]" >&2
		return 1
	fi
	local target="${BASHY_DOWNLOAD_CACHE}/${basename}"
	# The filename alone cannot say whether the cached copy is current: rolling
	# releases keep one name forever (buck2 always ships
	# buck2-x86_64-unknown-linux-gnu.zst) so a hit here would pin the first build we
	# ever downloaded. Remember the origin validator next to the file and re-check it.
	local etag_file="${target}.etag"
	if [ -s "${target}" ]
	then
		local cached_tag=""
		if [ -f "${etag_file}" ]
		then
			cached_tag=$(cat "${etag_file}")
		fi
		local remote_tag
		remote_tag=$(_bashy_download_validator "${url}")
		if [ -n "${cached_tag}" ] && [ "${cached_tag}" = "${remote_tag}" ]
		then
			bashy_log "core/download" "${BASHY_LOG_INFO}" "cache hit for [${basename}]"
			_bashy_download_return "${target}" "${2-}"
			return 0
		fi
		if [ -z "${remote_tag}" ]
		then
			# offline, or the origin serves no validator - the cached copy is all we have
			bashy_log "core/download" "${BASHY_LOG_INFO}" "cannot revalidate [${basename}], using cached copy"
			_bashy_download_return "${target}" "${2-}"
			return 0
		fi
		bashy_log "core/download" "${BASHY_LOG_INFO}" "[${basename}] changed upstream, refetching"
	fi
	bashy_log "core/download" "${BASHY_LOG_INFO}" "downloading [${url}]"
	mkdir -p "${BASHY_DOWNLOAD_CACHE}"
	# download to a temp file in the cache dir so an interrupted download
	# never leaves a truncated file that would later look like a cache hit
	local tmp="${target}.part"
	local rc=0
	curl --fail --location --silent --show-error "${url}" --output "${tmp}" || rc=$?
	if [ "${rc}" -ne 0 ]
	then
		# curl has already printed its own reason above; the exit code says which
		# kind of failure it was (6 dns, 7 connect, 18 partial, 22 http error,
		# 28 timeout, 56 receive error), and the byte count how far it got
		local got=0
		[ -f "${tmp}" ] && got=$(stat --format=%s "${tmp}")
		echo "bashy_download: failed to download [${url}]: curl exit ${rc}, ${got} bytes received" >&2
		rm -f "${tmp}"
		return 1
	fi
	mv -f "${tmp}" "${target}"
	# record what we just fetched so the next run can tell whether it is still current
	local new_tag
	new_tag=$(_bashy_download_validator "${url}")
	if [ -n "${new_tag}" ]
	then
		echo "${new_tag}" > "${etag_file}"
	else
		rm -f "${etag_file}"
	fi
	_bashy_download_return "${target}" "${2-}"
}

# bashy_verify_sha256 <file> <checksums url or literal sha256>
# Check <file> against a published sha256.
#
# The second argument is either a bare 64 character digest or the url of a
# checksums file in the usual "<digest> <filename>" sha256sum format. That covers
# both shapes upstreams publish: a single .sha256sum next to the artifact and a
# combined checksums.txt listing every asset of the release.
#
# Returns 0 when the digest matches, 1 when it does not or cannot be established.
# A mismatch means the bytes are not what the project published - never install them.
function bashy_verify_sha256() {
	local file=$1
	local source=$2
	if [ ! -s "${file}" ]
	then
		echo "bashy_verify_sha256: no such file [${file}]" >&2
		return 1
	fi
	local expected=""
	if [[ "${source}" =~ ^[0-9a-fA-F]{64}$ ]]
	then
		expected="${source}"
	else
		local sums
		if ! sums=$(curl --fail --location --silent --show-error "${source}")
		then
			echo "bashy_verify_sha256: could not fetch checksums from [${source}]" >&2
			return 1
		fi
		# some projects publish a bare digest with no filename column at all
		local stripped="${sums//[[:space:]]/}"
		if [[ "${stripped}" =~ ^[0-9a-fA-F]{64}$ ]]
		then
			expected="${stripped}"
		else
			# Match on the basename. The listed name may carry a "*" binary marker and
			# may be a path rather than a bare name - rustup publishes
			# "<digest> *./rustup-init" - so strip both before comparing.
			local want="${file##*/}"
			expected=$(echo "${sums}" | awk -v want="${want}" \
				'{name=$2; sub(/^\*/,"",name); sub(/.*\//,"",name); if(name==want){print $1; exit}}')
			if [ -z "${expected}" ]
			then
				echo "bashy_verify_sha256: [${want}] not listed in [${source}]" >&2
				return 1
			fi
		fi
	fi
	local actual
	actual=$(sha256sum "${file}" | awk '{print $1}')
	if [ "${actual,,}" != "${expected,,}" ]
	then
		echo "bashy_verify_sha256: checksum mismatch for [${file}]" >&2
		echo "expected [${expected}]" >&2
		echo "actual [${actual}]" >&2
		return 1
	fi
	# never let the logger decide the result of a verification
	bashy_log "core/download" "${BASHY_LOG_INFO:-}" "sha256 verified for [${file##*/}]" 2>/dev/null || true
	return 0
}

# bashy_download_clean
# Remove the entire download cache.
function bashy_download_clean() {
	if [ -d "${BASHY_DOWNLOAD_CACHE}" ]
	then
		echo "removing download cache [${BASHY_DOWNLOAD_CACHE}]"
		rm -rf "${BASHY_DOWNLOAD_CACHE}"
	else
		echo "no download cache at [${BASHY_DOWNLOAD_CACHE}]"
	fi
}
