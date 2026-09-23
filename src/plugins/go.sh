# GOBIN - is where executbles are installed
# GOPATH - is where go is installed
# You don't need them both as executables are installed into ${GOPATH}/bin if ${GOBIN} is undefined.
# ~/.cache/go-build is where the go cache is
# GOROOT - where go is installed


function _activate_go() {
	local -n __var=$1
	local -n __error=$2
	# GOPATH="${HOME}/.cache/go"
	GOROOT="${HOME}/install/go"
	GOPATH="${HOME}/install/gopath"
	GOBIN="${GOPATH}/bin"
	if ! checkDirectoryExists "${GOROOT}" __var __error; then return; fi
	if ! checkDirectoryExists "${GOPATH}" __var __error; then return; fi
	if ! checkDirectoryExists "${GOBIN}" __var __error; then return; fi
	export GOPATH
	# export GOBIN
	_bashy_pathutils_add_head PATH "${GOBIN}"
	complete -C gocomplete go
	__var=0
}

function _install_go() {
	# https://go.dev/dl/
	local folder="${HOME}/install"
	local full_folder="${folder}/go"
	local latest_version
	latest_version=$(curl --fail --show-error --silent "https://go.dev/VERSION?m=text" | grep -o "[0-9]\+\.[0-9]\+\.[0-9]\+")
	local executable="${full_folder}/bin/go"
	local installed_version=""
	if [ -x "${executable}" ]
	then
		installed_version=$("${executable}" version 2>/dev/null | grep -oP 'go\K[0-9]+\.[0-9]+\.[0-9]+' | head -1)
	fi
	if bashy_install_check "go" "${installed_version}" "${latest_version}"
	then
		return
	fi
	local download_file="https://go.dev/dl/go${latest_version}.linux-amd64.tar.gz"
	bashy_install_download "${download_file}"
	local tar
	bashy_download "${download_file}" tar || return
	# go publishes the sha256 of each archive on its download page
	local expected
	expected=$(curl --fail --silent --location "https://go.dev/dl/?mode=json&include=all" \
		| jq --raw-output --arg f "go${latest_version}.linux-amd64.tar.gz" \
			'.[].files[] | select(.filename==$f) | .sha256' | head -1)
	if [ -n "${expected}" ]
	then
		bashy_verify_sha256 "${tar}" "${expected}" || return
	fi
	rm -rf "${full_folder}"
	bashy_install_extract "${tar}" "${folder}"
	rm -rf "${HOME}/.cache/go-build" "${HOME}/install/gopath"
	mkdir -p "${HOME}/install/gopath/bin"
}
function _uninstall_go() {
	bashy_uninstall_directory "go" "${HOME}/install/go" "${HOME}/install/gopath"
}

# Undo the activation in the running shell, for bashy_deactivate.
function _deactivate_go() {
	_bashy_pathutils_remove PATH "${HOME}/install/gopath/bin"
	unset GOPATH
	complete -r go 2> /dev/null
}

register _activate_go _deactivate_go
