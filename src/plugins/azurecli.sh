# azure completion is in /etc/bash_completion.d/azure-cli
# and comes with the azure tools deb package
# 
# Documentation about how to install the azure cli tools:
# https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-linux?pivots=apt

function _install_azurecli() {
	bashy_install_args "$@" || return
	# the deb variant is Microsoft's recommended path on debian/ubuntu: apt owns
	# the package once installed, so updates and signature checking are handled by
	# apt itself, and nothing downloaded over the network is executed as root
	_install_azurecli_deb "$@"
}

# recommended
#
# This does by hand exactly what Microsoft's InstallAzureCLIDeb script does: add
# their signing key, add their apt repository, install azure-cli from it. Doing it
# here rather than piping their script into "sudo bash" means nothing downloaded
# over the network is ever executed as root, and after this apt owns the package,
# so updates and signature checking are handled by apt itself.
#
# Upstream script, for comparison: https://aka.ms/InstallAzureCLIDeb
function _install_azurecli_deb() {
	bashy_install_args "$@" || return
	local keyring="/etc/apt/keyrings/microsoft.gpg"
	local sources="/etc/apt/sources.list.d/azure-cli.sources"
	bashy_install_apt "azure-cli prerequisites" \
		apt-transport-https ca-certificates curl gnupg lsb-release || return 1
	# the key is armoured, dearmour it into the keyring apt expects
	local key
	bashy_download "https://packages.microsoft.com/keys/microsoft.asc" key || return 1
	sudo mkdir -p /etc/apt/keyrings
	gpg --dearmor < "${key}" | sudo tee "${keyring}" > /dev/null
	sudo chmod go+r "${keyring}"
	# microsoft does not publish a repository for every dist, and their script falls
	# back to jammy on ubuntu, so do the same rather than failing on a new release
	local repo
	repo=$(lsb_release -cs)
	if ! curl --fail --silent --location "https://packages.microsoft.com/repos/azure-cli/dists/" | grep -q "${repo}"
	then
		local dist
		dist=$(lsb_release -is)
		case "${dist}" in
			Ubuntu|LinuxMint) repo="jammy" ;;
			Debian) repo="bookworm" ;;
			*)
				echo "no azure-cli repository for [${dist} ${repo}], see https://packages.microsoft.com/repos/azure-cli/dists/" >&2
				return 1
				;;
		esac
		echo "no azure-cli repository for this dist, falling back to [${repo}]"
	fi
	# the old style .list file would shadow the .sources one
	sudo rm -f /etc/apt/sources.list.d/azure-cli.list
	local new_sources
	new_sources=$(printf 'Types: deb\nURIs: https://packages.microsoft.com/repos/azure-cli/\nSuites: %s\nComponents: main\nArchitectures: %s\nSigned-by: %s\n' \
		"${repo}" "$(dpkg --print-architecture)" "${keyring}")
	if [ ! -f "${sources}" ] || [ "$(cat "${sources}" 2>/dev/null)" != "${new_sources}" ]; then
		echo "${new_sources}" | sudo tee "${sources}" > /dev/null
		unset _BASHY_APT_UPDATED
	fi
	bashy_install_apt "azure-cli" "azure-cli"
}

# The standalone installer is a python bootstrap with no packaged equivalent, so
# there is nothing to reimplement here. Download it first and run that file, rather
# than piping it into a root shell, so there is something on disk to look at.
function _install_azurecli_standalone() {
	bashy_install_args "$@" || return
	# the vendor script registers the apt repository and installs from it, so
	# the az it leaves behind is whichever one is first in PATH
	local installed_version latest_version
	_bashy_azurecli_versions "$(command -v az || true)" installed_version latest_version || return 1
	if bashy_install_check "azure-cli" "${installed_version}" "${latest_version}"
	then
		return
	fi
	echo "Installing azure-cli via the vendor install script"
	local script
	bashy_download "https://aka.ms/InstallAzureCLI" script || return 1
	echo "running [${script}] as root, inspect it first if you like"
	sudo bash "${script}"
}

# The tarball install has never worked: the bundle expects to build its own python
# and fails part way through. Kept so the approach is not tried again from scratch.
# _bashy_azurecli_versions <az executable> <installed out_var> <latest out_var>
# Work out the newest azure-cli release and the version <az executable> reports,
# for the variants below that install something apt does not own.
function _bashy_azurecli_versions() {
	local executable=$1
	local -n __installed=$2
	local -n __latest=$3
	local release_json
	bashy_github_release "Azure/azure-cli" release_json || return 1
	# releases are tagged "azure-cli-2.90.0"
	__latest=$(bashy_github_version "${release_json}" "azure-cli-")
	__installed=""
	if [ -x "${executable}" ]
	then
		# the first line of --version is "azure-cli   2.90.0"
		__installed=$("${executable}" --version 2>/dev/null | awk '/^azure-cli /{print $2; exit}')
	fi
}

function _install_azurecli_tarball() {
	bashy_install_args "$@" || return
	local folder="${HOME}/install/azurecli"
	local installed_version latest_version
	_bashy_azurecli_versions "${folder}/bin/az" installed_version latest_version || return 1
	if bashy_install_check "azure-cli" "${installed_version}" "${latest_version}"
	then
		return
	fi
	# the tarball has no versioned name, it is whatever the latest release is
	local download_file="https://azurecliprod.blob.core.windows.net/msi/azure-cli-latest.tar.gz"
	echo "Installing azure-cli from a tarball into [${folder}]"
	bashy_install_download "${download_file}"
	local archive
	bashy_download "${download_file}" archive || return 1
	rm -rf "${folder}"
	# unpack into a private directory, a predictable path under /tmp is a
	# world writable place and anyone could have created it first
	local tmp_dir
	tmp_dir=$(mktemp --directory)
	bashy_install_extract "${archive}" "${tmp_dir}" || { rm -rf "${tmp_dir}"; return 1; }
	# the tarball unpacks into a single versioned directory
	local extracted
	extracted=$(find "${tmp_dir}" -mindepth 1 -maxdepth 1 -type d)
	if [ -z "${extracted}" ]
	then
		echo "azure-cli: the tarball did not unpack into a directory" >&2
		rm -rf "${tmp_dir}"
		return 1
	fi
	"${extracted}/install" --install-dir "${folder}" --bin-dir "${folder}/bin"
	rm -rf "${tmp_dir}"
}

function _install_azurecli_extensions() {
	bashy_install_args "$@" || return
	echo "Installing azure-cli extensions [azure-devops]"
	# az refuses to add an extension that is already there, and --upgrade is its
	# way of saying "install it, or move it forward if it is already installed"
	az extension add --upgrade --name "azure-devops"
}

function _uninstall_azurecli() {
	bashy_uninstall_apt "azure-cli" "azure-cli"
}

function _activate_azurecli() {
	local -n __var=$1
	local -n __error=$2
	# bash completion for az(1) works out of the box because the "azure-cli" package
	# installs bash completion files in /etc/bash_completion.d/azure-cli
	__var=0
}

function _activate_azurecli_manual() {
	local -n __var=$1
	local -n __error=$2
	local install_dir="${HOME}/install/azurecli"
	local bin_dir="${install_dir}/bin"
	local completion_script="${install_dir}/az.completion"

	if [ -d "${bin_dir}" ]; then
		_bashy_pathutils_add_head PATH "${bin_dir}"
	fi

	if ! checkInPath "az" __var __error; then return; fi

	if [ -f "${completion_script}" ]; then
		# shellcheck source=/dev/null
		source "${completion_script}"
	fi
	__var=0
}

register_install _install_azurecli_deb
register_interactive _activate_azurecli
