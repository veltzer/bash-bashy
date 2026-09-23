# this is a plugin to install and uninstall vscode from ubuntu 

MSRING="/etc/apt/keyrings/microsoft.gpg"
MSKEYID="EB3E94ADBE1229CF"
MSAPT="/etc/apt/sources.list.d/vscode.sources"
PACKAGE_NAME="code"

function _install_code_apt() {
	if [ ! -f "${MSAPT}" ]
	then
		sudo gpg --keyserver "keyserver.ubuntu.com" --recv-keys "${MSKEYID}"
		sudo gpg --export --armor "${MSKEYID}" | sudo gpg --dearmor -o "${MSRING}"
		sudo tee "${MSAPT}" > /dev/null << EOF
Types: deb
URIs: https://packages.microsoft.com/repos/code
Suites: stable
Components: main
Architectures: amd64
Signed-By: ${MSRING}
EOF
	fi
	bashy_install_apt "code" "code"
}

function _install_code_direct() {
	# Get the latest version available from the VS Code update API
	local latest_version
	latest_version=$(curl --fail --silent --location "https://update.code.visualstudio.com/api/update/linux-deb-x64/stable/latest" | jq --raw-output '.productVersion')
	local installed_version=""
	if _bashy_pathutils_is_in_path "code"
	then
		installed_version=$(code --version 2>/dev/null | head -1)
	fi
	if bashy_install_check "code" "${installed_version}" "${latest_version}"
	then
		return
	fi
	# the update api serves the deb itself from a versioned url, which is what the
	# download cache needs to tell one build from the next
	bashy_install_deb "code" "https://update.code.visualstudio.com/${latest_version}/linux-deb-x64/stable"
}

function _uninstall_code() {
	bashy_uninstall_apt "code" "${PACKAGE_NAME}"
	if sudo gpg --list-keys "${MSKEYID}" &> /dev/null
	then
		echo "removing ${MSKEYID}"
		sudo gpg --delete-keys --batch --yes "${MSKEYID}"
	else
		echo "no ${MSKEYID} detected"
	fi
	local file
	for file in "${MSAPT}" "${MSRING}"
	do
		if [ -f "${file}" ]
		then
			echo "removing ${file}"
			sudo rm -f "${file}"
		else
			echo "no ${file} detected"
		fi
	done
	sudo apt-get update
}

function _activate_code() {
	local -n __var=$1
	local -n __error=$2
	__var=0
}

register_install _install_code_apt
register_interactive _activate_code
