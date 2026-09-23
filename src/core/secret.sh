# Secrets from pass(1), fetched when a command needs them.
#
# Five plugins used to run "pass show" at every shell start and export the result
# (ANTHROPIC_API_KEY, OPENAI_API_KEY, ...). Each lookup is a gpg decryption of
# about eight processes, so that was a good part of shell startup, and the keys
# then sat in the environment of every process the shell ever launched.
#
# bashy_with_secret runs one command with one variable set from pass, and nothing
# else sees it. A plugin wraps the tool in a function of the same name:
#
#	function claude() {
#		bashy_with_secret ANTHROPIC_API_KEY "keys/claude.ai" claude "$@"
#	}
#
# The command is started through env(1), which looks it up on PATH, so the
# wrapper does not call itself.

# bashy_with_secret <variable> <pass path> <command...>
# Run <command...> with <variable> set to the pass(1) entry at <pass path>.
# Returns 1 without running anything when the entry cannot be read.
function bashy_with_secret() {
	local variable=$1
	local path=$2
	shift 2
	local value
	if ! value=$(pass show "${path}" 2>/dev/null)
	then
		echo "${1}: cannot read [${path}] from pass(1)" >&2
		return 1
	fi
	env "${variable}=${value}" "$@"
}
