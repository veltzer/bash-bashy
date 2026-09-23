# This is a plugin for docker

function _activate_docker() {
	local -n __var=$1
	local -n __error=$2
	if ! checkInPath "docker" __var __error; then return; fi
	export DOCKER_HOST="unix:///var/run/docker.sock"
	__var=0
}

# Undo the activation in the running shell, for bashy_deactivate.
function _deactivate_docker() {
	unset DOCKER_HOST
}

register_interactive _activate_docker _deactivate_docker
