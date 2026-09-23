# This is a plugin for the redhat oc(1) client tool which is a superset of kubectl(1)
# for openshift based systems

function _activate_oc() {
	local -n __var=$1
	local -n __error=$2
	if ! checkInPath "oc" __var __error; then return; fi
	if ! bashy_completion oc oc completion bash
	then
		__var=$?
		__error="could not source oc completion"
		return
	fi
	__var=0
}

function _install_oc() {
	# instructions for installing oc are at
	# https://access.redhat.com/documentation/en-us/red_hat_build_of_microshift/4.12/html/cli_tools/microshift-oc-cli-install
	# But I'm using a different download link to account the need to log-in with a redhat account
	local base="https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest"
	local download_file="${base}/openshift-client-linux.tar.gz"
	local folder
	folder=$(bashy_install_dir)
	local executable="${folder}/oc"
	local latest_version
	latest_version=$(curl --fail --silent --location "${base}/release.txt" | grep -oP 'Version:\s+\K[0-9]+\.[0-9]+\.[0-9]+' | head -1)
	local installed_version=""
	if [ -x "${executable}" ]
	then
		installed_version=$("${executable}" version --client 2>/dev/null | grep -oP 'Client Version:\s+\K[0-9]+\.[0-9]+\.[0-9]+' | head -1)
	fi
	if bashy_install_check "oc" "${installed_version}" "${latest_version}"
	then
		return
	fi
	bashy_install_download "${download_file}"
	local tar
	bashy_download "${download_file}" tar || return
	bashy_verify_sha256 "${tar}" "${base}/sha256sum.txt" || return
	rm -f "${executable}"
	bashy_install_extract "${tar}" "${folder}" oc
}

function _uninstall_oc() {
	bashy_uninstall_binary "oc"
}

register _activate_oc
