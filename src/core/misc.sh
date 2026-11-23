# update just a single apt repo view
# References:
# http://askubuntu.com/questions/65245/apt-get-update-only-for-a-specific-repository
function update_repo() {
	for source in "$@"
	do
		sudo apt-get update -o Dir::Etc::sourcelist="sources.list.d/${source}" \
		-o Dir::Etc::sourceparts="-" -o APT::Get::List-Cleanup="0"
	done
}

# check if I am on a certain host, expects hostname
function is_hostname() {
	local name=$1
	[[ "${HOSTNAME}" = "${name}" ]]
}

# we check for interactivity using "$- == *i*"
function is_interactive() {
	[[ $- == *i* ]]
}

function _bashy_before_thirdparty() {
	:
}

function _bashy_after_thirdparty() {
	:
}

function before_strict() {
	:
	# set -e
}

function after_strict() {
	:
	# set +e
}
