# this is a configuation for awscli
# there were several versions of the awscli and so there are several versions in this code.
# the one which is enabled is the latest v2 cli client of aws and also the one mentioned in
# the references.
#
# References:
# - https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
#
# aws-iam-authenticator
# - https://docs.aws.amazon.com/eks/latest/userguide/install-aws-iam-authenticator.html
# - https://www.learnaws.org/2023/08/22/aws-iam-authenticator/

function _activate_awscli() {
	local -n __var=$1
	local -n __error=$2
	AWSCLI_HOME="${HOME}/install/aws"
	AWSCLI_HOME_BIN="${AWSCLI_HOME}/bin"
	if ! checkDirectoryExists "${AWSCLI_HOME}" __var __error; then return; fi
	if ! checkDirectoryExists "${AWSCLI_HOME_BIN}" __var __error; then return; fi
	_bashy_pathutils_add_head PATH "${AWSCLI_HOME_BIN}"
	export AWSCLI_HOME
	__var=0
}

function _activate_awscli_wrapper() {
	local -n __var=$1
	local -n __error=$2
	# this is needed for the completer to work for the wrapper version
	# alias aws='awsv2'
	__var=0
}

function _install_awscli_wrapper() {
	# installation of a pip wrapper - this is not the official aws client
	bashy_install_pip "awscliv2" "awscliv2"
}

function _install_awscli() {
	local folder="${HOME}/install/aws"
	local executable="${folder}/bin/aws"
	local latest_version
	latest_version=$(curl --fail --silent --location "https://api.github.com/repos/aws/aws-cli/tags?per_page=20" | jq --raw-output '[.[] | select(.name | startswith("2."))][0].name')
	local installed_version=""
	if [ -x "${executable}" ]
	then
		installed_version=$("${executable}" --version 2>/dev/null | grep -oP 'aws-cli/\K[0-9]+\.[0-9]+\.[0-9]+' | head -1)
	fi
	if bashy_install_check "awscli" "${installed_version}" "${latest_version}"
	then
		return
	fi
	local download_file="https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
	bashy_install_download "${download_file}"
	local archive
	bashy_download "${download_file}" archive || return
	# aws signs its installer with gpg rather than publishing a sha256, so there
	# is nothing to hand bashy_verify_sha256 here
	rm -rf "${folder}"
	# unpack into a private directory, /tmp/aws is a predictable path in a
	# world writable place and anyone could have created it first
	local tmp_dir
	tmp_dir=$(mktemp --directory)
	bashy_install_extract "${archive}" "${tmp_dir}" || { rm -rf "${tmp_dir}"; return 1; }
	"${tmp_dir}/aws/install" --install-dir "${folder}" --bin-dir "${folder}/bin" > /dev/null
	rm -rf "${tmp_dir}"
	# the old pypi "awscli" shadows this one in PATH, so it has to go
	if pip show awscli > /dev/null 2>&1
	then
		bashy_uninstall_pip "the old pypi awscli" "awscli"
	fi
	# eks needs the authenticator alongside the client, install it in the same pass
	_install_aws_iam_authenticator
}

function _install_aws_iam_authenticator() {
	local release_json
	bashy_github_release "kubernetes-sigs/aws-iam-authenticator" release_json || return
	local latest_version
	latest_version=$(bashy_github_version "${release_json}")
	local executable="${HOME}/install/aws/bin/aws-iam-authenticator"
	local installed_version=""
	if [ -x "${executable}" ]
	then
		installed_version=$("${executable}" version 2>/dev/null | grep -oP '"Version":"v?\K[^"]+' | head -1)
	fi
	if bashy_install_check "aws-iam-authenticator" "${installed_version}" "${latest_version}"
	then
		return
	fi
	local download_file
	bashy_github_asset "${release_json}" "_linux_amd64$" download_file || return
	local binary
	bashy_download "${download_file}" binary || return
	local checksums
	if bashy_github_asset "${release_json}" "_checksums\\.txt$" checksums 2>/dev/null
	then
		bashy_verify_sha256 "${binary}" "${checksums}" || return
	fi
	bashy_install_binary "aws-iam-authenticator" "${download_file}" "${executable}"
}

function _uninstall_awscli() {
	bashy_uninstall_directory "awscli" "${HOME}/install/aws"
}

function awscli_select_profile() {
	readarray -t profiles < <(sed -nr 's/^\[(.*)\]$/\1/p' "${HOME}/.aws/credentials")
	echo "Please select a profile:"
	select profile in "${profiles[@]}"; do
		[[ -n "${profile}" ]] || { echo "Invalid choice. Please try again." >&2; continue; }
		break
	done
	echo "selected [${profile}]..."
	export AWS_PROFILE="${profile}"
}

# Undo the activation in the running shell, for bashy_deactivate.
function _deactivate_awscli() {
	_bashy_pathutils_remove PATH "${HOME}/install/aws/bin"
	unset AWSCLI_HOME
}

register _activate_awscli _deactivate_awscli
register_install _install_awscli
