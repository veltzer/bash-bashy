function _activate_bash_completions_userdir() {
	local -n __var=$1
	local -n __error=$2
	# my own bash completions
	# note that the 'source' command in bash cannot
	# sources more than one file at a time so we must
	# use the loop below....
	local FOLDER="${HOME}/.bash_completion.d"
	# check if there are files matching the pattern
	if compgen -G "${FOLDER}"/* > /dev/null
	then
		# source the files
		for x in "${FOLDER}"/*
		do
			if [[ -f "${x}" ]] && [[ -r "${x}" ]]
			then
				# shellcheck source=/dev/null
				source "${x}"
			fi
		done
	fi
	__var=0
}

register_interactive _activate_bash_completions_userdir
