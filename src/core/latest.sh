# Cache for "what is the latest version" queries.
#
# Every installer starts by asking its project what the latest release is, so a
# bashy_upgrade fires one query per plugin, and running it twice in a row asks
# the same questions again. Github allows 60 unauthenticated api calls an hour,
# which a couple of runs use up.
#
# bashy_fetch_latest is curl for those queries: it keeps the answer, and for
# BASHY_LATEST_TTL seconds returns the kept answer instead of
# asking again. It caches the whole response, not just the version taken out of
# it, because installers read more than the version from the same answer - the
# asset url, a checksum - and those have to agree with the version.
#
# Usage from a plugin, in place of "curl --fail --silent --location <url>":
#
#	local json
#	bashy_fetch_latest "https://api.github.com/repos/${repo}/releases/latest" json || return 1
#
# --refresh (or --force) to an installer skips the cache and asks again; the
# fresh answer replaces the kept one.
#
# One file per url, named by the sha256 of the url: its content is the response
# and its mtime is when it was fetched. A <hash>.url file beside it holds the url,
# for bashy_latest_list. Only successful fetches are kept, so an outage or a rate
# limit answer is never mistaken for the latest release.
#
# Caching the answers alone does not make a second bashy_upgrade fast: every
# installer still runs, asks the tool for its installed version, and the npm,
# pip and git ones redo their whole install. So bashy_upgrade also keeps, under
# upgrade/ in the same cache, one empty file per plugin whose installer
# succeeded, and skips that plugin while the file is younger than
# BASHY_LATEST_TTL - the same interval in which its latest version would come
# from the cache anyway. --refresh and --force run every installer again.

# location of the cache, honoring XDG_CACHE_HOME, overridable via BASHY_LATEST_CACHE
if [ -z "${BASHY_LATEST_CACHE+x}" ]
then
	export BASHY_LATEST_CACHE="${XDG_CACHE_HOME:-${HOME}/.cache}/bashy/latest"
fi

# how long an answer stays fresh, in seconds, overridable via BASHY_LATEST_TTL;
# this is the one place the default is set, everything else refers to the variable
if [ -z "${BASHY_LATEST_TTL+x}" ]
then
	export BASHY_LATEST_TTL=$(( 24 * 60 * 60 ))
fi

# _bashy_latest_file <url> <out_var>
# The cache file that holds the answer for <url>.
function _bashy_latest_file() {
	local -n __file=$2
	local hash
	hash=$(printf '%s' "$1" | sha256sum)
	__file="${BASHY_LATEST_CACHE}/${hash%% *}"
}

# _bashy_latest_age <file> <out_var>
# The age of <file> in seconds.
function _bashy_latest_age() {
	local -n __age=$2
	local now mtime
	printf -v now '%(%s)T' -1
	mtime=$(stat --format=%Y "$1")
	__age=$(( now - mtime ))
}

# _bashy_latest_fresh <file> <age_var>
# Succeed when <file> exists and is younger than BASHY_LATEST_TTL seconds, and
# put its age into <age_var>.
function _bashy_latest_fresh() {
	local -n __fresh_age=$2
	[ -f "$1" ] || return 1
	_bashy_latest_age "$1" __fresh_age
	# a negative age is a clock that went backwards, not a fresh answer
	[ "${__fresh_age}" -ge 0 ] && [ "${__fresh_age}" -lt "${BASHY_LATEST_TTL}" ]
}

# bashy_fetch_latest <url> [out_var]
# The body of <url>, from the cache when it was fetched less than
# BASHY_LATEST_TTL seconds ago and the installer was not given --refresh or
# --force, otherwise from the network. Assigns to out_var when given, otherwise
# echoes. Returns 1 when the fetch fails.
function bashy_fetch_latest() {
	local __latest_url=$1
	local __latest_file
	_bashy_latest_file "${__latest_url}" __latest_file
	local __latest_body __latest_age
	local __latest_hit=0
	if [ "${BASHY_INSTALL_REFRESH:-0}" -ne 1 ] && _bashy_latest_fresh "${__latest_file}" __latest_age
	then
		bashy_log "core/latest" "${BASHY_LOG_INFO}" "cache hit for [${__latest_url}], ${__latest_age}s old"
		__latest_body=$(< "${__latest_file}")
		__latest_hit=1
	fi
	if [ "${__latest_hit}" -eq 0 ]
	then
		if ! __latest_body=$(curl --fail --silent --show-error --location "${__latest_url}")
		then
			echo "bashy_fetch_latest: could not fetch [${__latest_url}]" >&2
			return 1
		fi
		mkdir --parents "${BASHY_LATEST_CACHE}"
		# write beside the target and rename, so a reader never sees half an answer
		local __latest_tmp
		__latest_tmp=$(mktemp "${__latest_file}.XXXXXX")
		printf '%s' "${__latest_body}" > "${__latest_tmp}"
		mv --force "${__latest_tmp}" "${__latest_file}"
		printf '%s\n' "${__latest_url}" > "${__latest_file}.url"
	fi
	if [ -n "${2:-}" ]
	then
		local -n __out=$2
		__out="${__latest_body}"
	else
		printf '%s\n' "${__latest_body}"
	fi
}

# bashy_upgrade_fresh <plugin>
# Succeed when bashy_upgrade ran the installer of <plugin> successfully less
# than BASHY_LATEST_TTL seconds ago.
function bashy_upgrade_fresh() {
	local age
	_bashy_latest_fresh "${BASHY_LATEST_CACHE}/upgrade/$1" age
}

# bashy_upgrade_mark <plugin>
# Record that the installer of <plugin> just ran successfully.
function bashy_upgrade_mark() {
	mkdir --parents "${BASHY_LATEST_CACHE}/upgrade"
	touch "${BASHY_LATEST_CACHE}/upgrade/$1"
}

# bashy_latest_list
# Show every cached answer: its age in seconds and the url it answers.
function bashy_latest_list() {
	local url_file age
	for url_file in "${BASHY_LATEST_CACHE}"/*.url
	do
		[ -f "${url_file}" ] || continue
		[ -f "${url_file%.url}" ] || continue
		_bashy_latest_age "${url_file%.url}" age
		printf '%8ss  %s\n' "${age}" "$(< "${url_file}")"
	done
}

# bashy_latest_clean
# Remove the entire cache, so the next installer asks again and the next
# bashy_upgrade runs every installer.
function bashy_latest_clean() {
	if [ -d "${BASHY_LATEST_CACHE}" ]
	then
		echo "removing latest version cache [${BASHY_LATEST_CACHE}]"
		rm -rf "${BASHY_LATEST_CACHE}"
	else
		echo "no latest version cache at [${BASHY_LATEST_CACHE}]"
	fi
}
