# This is a plugin to help you work with minikube
# It does NOT define the MINIKUBE_HOME which default is to ~

function _activate_minikube() {
	local -n __var=$1
	local -n __error=$2
	if ! checkInPath "minikube" __var __error; then return; fi
	if ! bashy_completion minikube minikube completion bash
	then
		__var=$?
		__error="could not source minikube completion"
		return
	fi
	__var=0
}

function _install_minikube() {
	# https://minikube.sigs.k8s.io/docs/start/
	local release_json
	bashy_github_release "kubernetes/minikube" release_json || return
	local latest_version
	latest_version=$(bashy_github_version "${release_json}")
	local folder
	folder=$(bashy_install_dir)
	local executable="${folder}/minikube"
	local installed_version=""
	if [ -x "${executable}" ]
	then
		installed_version=$("${executable}" version 2>/dev/null | grep -oP 'minikube version: v\K[0-9]+\.[0-9]+\.[0-9]+' | head -1)
	fi
	if bashy_install_check "minikube" "${installed_version}" "${latest_version}"
	then
		return
	fi
	local download_file
	bashy_github_asset "${release_json}" "minikube-linux-amd64$" download_file || return
	local binary
	bashy_download "${download_file}" binary || return
	bashy_verify_sha256 "${binary}" "${download_file}.sha256" || return
	bashy_install_binary "minikube" "${download_file}" "${executable}"
}

function _uninstall_minikube() {
	bashy_uninstall_binary "minikube"
}

register_interactive _activate_minikube
