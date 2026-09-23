function _activate_terraform() {
	local -n __var=$1
	local -n __error=$2
	if ! checkInPath "terraform" __var __error; then return; fi
	complete -C "terraform" terraform
	__var=0
}

function _install_terraform() {
	# latest version: https://github.com/hashicorp/terraform/issues/9803
	local latest_version
	latest_version=$(curl --fail --silent "https://checkpoint-api.hashicorp.com/v1/check/terraform" | jq --raw-output --monochrome-output ".current_version")
	local folder
	folder=$(bashy_install_dir)
	local executable="${folder}/terraform"
	local installed_version=""
	if [ -x "${executable}" ]
	then
		installed_version=$("${executable}" version 2>/dev/null | grep -oP '^Terraform v\K[0-9]+\.[0-9]+\.[0-9]+' | head -1)
	fi
	if bashy_install_check "terraform" "${installed_version}" "${latest_version}"
	then
		return
	fi
	local base="https://releases.hashicorp.com/terraform/${latest_version}"
	local download_file="${base}/terraform_${latest_version}_linux_amd64.zip"
	bashy_install_download "${download_file}"
	local archive
	bashy_download "${download_file}" archive || return
	bashy_verify_sha256 "${archive}" "${base}/terraform_${latest_version}_SHA256SUMS" || return
	rm -f "${executable}"
	bashy_install_extract "${archive}" "${folder}" terraform
}

function _uninstall_terraform() {
	bashy_uninstall_binary "terraform"
}

# Undo the activation in the running shell, for bashy_deactivate. The completion is dropped; the functions it defined stay, unused.
function _deactivate_terraform() {
	complete -r terraform 2> /dev/null
}

register_interactive _activate_terraform _deactivate_terraform
