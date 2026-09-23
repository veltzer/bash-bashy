function _activate_packer() {
	local -n __var=$1
	local -n __error=$2
	if ! checkInPath "packer" __var __error; then return; fi
	complete -C "packer" packer
	__var=0
}

function _install_packer() {
	# latest version: https://github.com/hashicorp/terraform/issues/9803
	local latest_version
	latest_version=$(curl --fail --show-error --silent "https://checkpoint-api.hashicorp.com/v1/check/packer" | jq --raw-output --monochrome-output ".current_version")
	local folder
	folder=$(bashy_install_dir)
	local executable="${folder}/packer"
	local installed_version=""
	if [ -x "${executable}" ]
	then
		installed_version=$("${executable}" --version 2>/dev/null | grep -oP '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
	fi
	if bashy_install_check "packer" "${installed_version}" "${latest_version}"
	then
		return
	fi
	local base="https://releases.hashicorp.com/packer/${latest_version}"
	local download_file="${base}/packer_${latest_version}_linux_amd64.zip"
	bashy_install_download "${download_file}"
	local archive
	bashy_download "${download_file}" archive || return
	bashy_verify_sha256 "${archive}" "${base}/packer_${latest_version}_SHA256SUMS" || return
	rm -f "${executable}"
	bashy_install_extract "${archive}" "${folder}" packer
}

function _uninstall_packer() {
	bashy_uninstall_binary "packer"
}

register_interactive _activate_packer
