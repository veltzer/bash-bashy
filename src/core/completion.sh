# Cached shell completions.
#
# Most tools ship their bash completion by printing it: "minikube completion bash",
# "gh completion -s bash", "starship init bash". Running those at every shell start
# is what made bashy slow - each one is a process spawn, and minikube alone takes
# over a tenth of a second.
#
# The output only changes when the tool itself changes, so generate it once, keep it
# in a cache file, and source the file afterwards. The cache is keyed on the mtime
# of the tool's binary, so upgrading the tool regenerates it by itself.
#
# A cache hit costs no process at all. The tool's mtime is not read with stat(1)
# but copied onto a stamp file with "touch -r" when the cache is written, and the
# check afterwards is the builtin "-nt"/"-ot" test between the tool and that
# stamp, which compares to the nanosecond. It used to be a "stat" and a "cat" per
# tool, about 10 ms, which made the cache slower than the fast rs* tools it now
# serves as well.
#
# Usage from a plugin, in place of "source <(minikube completion bash)":
#
#	bashy_completion minikube minikube completion bash
#
# The first argument is the tool whose binary keys the cache, the rest is the
# command to run. Returns non zero if the tool is missing or the command fails,
# so a plugin can report it the usual way:
#
#	if ! bashy_completion uv uv --generate-shell-completion bash
#	then
#		__var=1
#		__error="could not load uv completion"
#		return
#	fi

# location of the cache, honoring XDG_CACHE_HOME, overridable via BASHY_COMPLETION_CACHE
if [ -z "${BASHY_COMPLETION_CACHE+x}" ]
then
	export BASHY_COMPLETION_CACHE="${XDG_CACHE_HOME:-${HOME}/.cache}/bashy/completions"
fi

# bashy_completion <tool> <command...>
# Source the bash completion produced by <command...>, through a cache keyed on the
# binary of <tool>. Returns 0 on success, non zero when the tool is absent or the
# command fails.
function bashy_completion() {
	local tool=$1
	shift
	# "type -P" gives the binary on PATH even when a plugin wrapped the tool in a
	# function of the same name (uv, cargo, ...). "command -v" would return the
	# function's name, and a name that is not a file is "older" than any stamp,
	# so the cache would regenerate on every shell.
	local path
	if ! path=$(type -P "${tool}" 2>/dev/null) || [ -z "${path}" ]
	then
		return 1
	fi
	local cache="${BASHY_COMPLETION_CACHE}/${tool}.bash"
	local stamp_file="${cache}.stamp"
	# Regenerate when we have never run it, or when the tool's mtime differs from
	# the one the stamp carries, in either direction: a package manager can put a
	# binary in place with a build date older than the stamp, and a plain "newer
	# than" test would keep serving the old completion for it.
	if [ ! -s "${cache}" ] || [ ! -e "${stamp_file}" ] \
		|| [ "${path}" -nt "${stamp_file}" ] || [ "${path}" -ot "${stamp_file}" ]
	then
		mkdir -p "${BASHY_COMPLETION_CACHE}"
		local tmp="${cache}.$$"
		# "command" runs the binary, not a function or alias wrapped around it
		if ! command "$@" > "${tmp}" 2>/dev/null || [ ! -s "${tmp}" ]
		then
			rm -f "${tmp}"
			return 1
		fi
		mv -f "${tmp}" "${cache}"
		touch -r "${path}" "${stamp_file}"
	fi
	# shellcheck source=/dev/null
	source "${cache}"
}

# bashy_completion_clean
# Drop the completion cache, so every tool regenerates on the next shell.
function bashy_completion_clean() {
	if [ -d "${BASHY_COMPLETION_CACHE}" ]
	then
		echo "removing completion cache [${BASHY_COMPLETION_CACHE}]"
		rm -rf "${BASHY_COMPLETION_CACHE}"
	else
		echo "no completion cache at [${BASHY_COMPLETION_CACHE}]"
	fi
}
