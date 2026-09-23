# this is a plugin for kubectl and the like
# provide install for latest kubectl
# provide bash completions for kubectl(1)

function _activate_k8s() {
	local -n __var=$1
	local -n __error=$2
	if ! checkInPath "kubectl" __var __error; then return; fi
	if ! bashy_completion kubectl kubectl completion bash; then
		__var=1
		__error="problem in sourcing kubectl completion"
		return
	fi
	__var=0
}

function _install_k8s() {
	# instructions for installing k8s are at
	# https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/
	local latest_version
	latest_version=$(curl --fail --silent --location "https://dl.k8s.io/release/stable.txt")
	local folder
	folder=$(bashy_install_dir)
	local executable="${folder}/kubectl"
	local installed_version=""
	if [ -x "${executable}" ]
	then
		installed_version=$("${executable}" version --client 2>/dev/null | grep -oP 'Client Version: \K[^\s]+' | head -1)
	fi
	if bashy_install_check "kubectl" "${installed_version}" "${latest_version}"
	then
		return
	fi
	local download_file="https://dl.k8s.io/release/${latest_version}/bin/linux/amd64/kubectl"
	local binary
	bashy_download "${download_file}" binary || return
	bashy_verify_sha256 "${binary}" "${download_file}.sha256" || return
	bashy_install_binary "kubectl" "${download_file}" "${executable}"
}

function _uninstall_k8s() {
	bashy_uninstall_binary "kubectl"
}

# Undo the activation in the running shell, for bashy_deactivate. The completion is dropped; the functions it defined stay, unused.
function _deactivate_k8s() {
	complete -r kubectl 2> /dev/null
}

register _activate_k8s _deactivate_k8s
