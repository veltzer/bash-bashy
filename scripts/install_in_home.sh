#!/bin/bash -eu

# Install bashy into ~/.bashy.
#
# What gets installed is listed in .includes, which is an allow list: its last line
# excludes everything, so anything not named there stays out of ~/.bashy.
#
# This is incremental. Files that are identical are neither printed nor copied, so
# the list below is exactly what changed. --delete removes anything in ~/.bashy that
# is no longer part of the install, which is what keeps a renamed or dropped plugin
# from lingering there.
#
# -c compares by checksum rather than size and mtime, so a file that was merely
# touched does not count as changed.
#
# After copying, the install is stamped: ~/.bashy/.stamp records the commit, the
# version and the time, and a running shell compares it with the one it read at
# startup to notice that a newer bashy has been installed under it (see
# src/core/stamp.sh). The stamp is only rewritten when something was copied, so
# a stamp change means a content change. It is not in .includes, and rsync leaves
# excluded files alone when it deletes, so the stamp survives --delete.

target="${HOME}/.bashy"

# The trailing slash makes rsync copy the contents of src/ rather than the
# directory itself, which is also what lets the allow list in .includes match the
# paths it names.
src="src/"

# rsync flags shared by the preview and the real run, so the preview cannot
# describe a different operation than the one that follows it
declare -a flags=(
	--archive
	--checksum
	--delete
	--itemize-changes
	--human-readable
	--include-from=.includes
)

# --dry-run prints the same itemized list the real run would, without touching disk.
#
# The itemize codes are "YXcstpoguax": position 3 is c for a content change, and a
# leading > or * marks a transfer or a deletion. A line where only t (mtime) differs
# means the content is identical and rsync is merely restoring the timestamp, which
# is not a change worth reporting. Keep only real ones.
changes=$(rsync "${flags[@]}" --dry-run "${src}" "${target}/" |
	grep -E '^(>|<|\*|c[dfLDS])' |
	grep -vE '^\.[fdLDS]\.\.t' ||
	true)

stamp="${target}/.stamp"

function write_stamp() {
	# an install from a tarball has no commit to name
	local commit
	commit=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
	# only the installed part counts as dirty, an edited README is not
	if [ -n "$(git status --porcelain -- "${src}" 2>/dev/null)" ]; then
		commit="${commit}+dirty"
	fi
	local version
	version=$(sed -n 's/^export BASHY_VERSION_STR="\(.*\)"/\1/p' "${src}core/version.sh")
	echo "${commit} ${version:-unknown} $(date +%s)" > "${stamp}"
}

if [ -z "${changes}" ]; then
	echo "${target} is up to date"
	# an install from before stamping gets its stamp without waiting for a change
	if [ ! -f "${stamp}" ]; then
		write_stamp
	fi
	exit 0
fi
echo "updating [${target}]:"
printf '  %s\n' "${changes}"

# the preview above is the report, so let the real run work quietly. It still has to
# carry --itemize-changes so that it is the same operation that was previewed.
rsync "${flags[@]}" "${src}" "${target}/" >/dev/null
write_stamp
