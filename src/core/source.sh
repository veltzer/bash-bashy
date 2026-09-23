# A set of functions that help you to source other sources
#
# Features:
# - a single place that centralizes sourcing code.
# - a protection against double inclusion.

# protect against double inclusion
if [ -n "${SOURCE-}" ]
then
	return
fi

SOURCE=1

declare -gA sourced=()

function _bashy_source_relative() {
	local file=$1
	local path="${BASH_SOURCE%/*}/${file}"
	if ! [ "${sourced[${path}]+muahaha}" ]
	then
		sourced[${path}]=1
		# shellcheck source=/dev/null
		source "${path}"
	fi
}

# The path is normalized in the shell rather than with realpath(1): that was one
# fork per core module and per plugin, a hundred processes and a third of every
# shell start. Bashy hands in absolute paths anyway, so all that is needed is to
# anchor a relative one and drop a leading "./", which is enough for the same file
# named the same way twice to be recognized. A symlink and its target are two
# names here, which bashy never mixes.
function _bashy_source_absolute() {
	local file=$1
	local path="${file#./}"
	if [[ "${path}" != /* ]]
	then
		path="${PWD}/${path}"
	fi
	if ! [ "${sourced[${path}]+muahaha}" ]
	then
		sourced[${path}]=1
		# shellcheck source=/dev/null
		source "${path}"
	fi
}
