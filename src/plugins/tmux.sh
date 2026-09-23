# This runs tmux at the start of a session.
#
# This plugin executes tmux which means it turned
# the current process into tmux.
# when tmux will run a shell again and will run bashy
# again we will know that we are in tmux already
# and will not run it again.
#
# This does not mean that this plugin should be run
# last. On the contrary. It should be run first to enable
# tmux to run bash which will run all plugins. Since
# the old bash turned into tmux (that's exec for you)
# then we don't need to old shell and any of the plugins
# that came before this one are wasted. That is why this
# should be the first plugin to run.
#
# currently this code follows the following flow:
# if a session already exists, attach to it
# if not - start a new session.
#
# the new algorithm
# check if there are any detached sessions to tmux
# if there are, offer a dialog to attach to them.
# if there are not, just start a new session.
#
# References:
# - https://davidtranscend.com/blog/check-tmux-session-exists-script/

function _activate_tmux() {
	local -n __var=$1
	local -n __error=$2
	if ! checkInPath tmux __var __error; then return; fi
	# if not in tmux, then run tmux
	# if in tmux, don't do anything
	if [[ -z ${TMUX+x} ]]
	then
		# "tmux ls" complains on stderr when no server is running, which is
		# exactly the case that leads to a new session below
		local -a sessions=()
		readarray -t sessions < <(tmux ls -F '#{session_name}' 2> /dev/null)
		if [ "${#sessions[@]}" -gt 0 ]
		then
			# one menu entry per session. This used to pass the list as one
			# quoted word, so the menu had a single entry holding every name.
			local sel
			select sel in "new" "${sessions[@]}"
			do
				break
			done
			if [ "${sel}" = "new" ]
			then
				exec tmux new-session
			else
				exec tmux attach-session -t "${sel}"
			fi
		else
			exec tmux new-session
		fi
	fi
	__var=0
}

function _activate_tmux_old() {
	local -n __var=$1
	local -n __error=$2
	if ! checkInPath "tmux" __var __error; then return; fi
	# if not in tmux
	if [[ -z ${TMUX+x} ]]
	then
		local session="0"
		if tmux has-session -t "${session}" 2> /dev/null
		then
			exec tmux attach-session -t "${session}"
		else
			exec tmux new-session -s "${session}"
		fi
	fi
	__var=0
}

register_interactive _activate_tmux
