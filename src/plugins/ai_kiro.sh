# This is integration of kiro, the AWS agentic IDE built on Code OSS
# https://kiro.dev

function _activate_ai_kiro() {
	local -n __var=$1
	local -n __error=$2
	__var=0
}

# Install the latest kiro IDE from its signed deb package.
# https://kiro.dev/downloads/
# Kiro's updater reads a per platform json naming the current release and three
# files beside it: the deb, a certificate.pem and a signature.bin. There is no
# sha256 to hand bashy_verify_sha256, so the deb is checked the way kiro checks
# it: the certificate has to chain to a CA the system trusts for code signing and
# name Amazon as its owner, and the signature has to verify against its key.
function _install_kiro() {
	bashy_install_args "$@" || return
	local arch
	case "$(uname -m)" in
		x86_64|amd64) arch="x64" ;;
		arm64|aarch64) arch="arm64" ;;
		*)
			echo "kiro: unsupported architecture [$(uname -m)]" >&2
			return 1
			;;
	esac
	local metadata
	if ! metadata=$(curl --fail --silent --location "https://prod.download.desktop.kiro.dev/stable/metadata-linux-${arch}-deb-stable.json")
	then
		echo "kiro: could not fetch the release metadata" >&2
		return 1
	fi
	local latest_version
	latest_version=$(echo "${metadata}" | jq --raw-output '.currentRelease // empty')
	# the package version carries a build suffix, "1.4.26-1792704898"
	local installed_version=""
	if _bashy_apt_installed "kiro"
	then
		installed_version=$(dpkg-query --show --showformat='${Version}' "kiro" 2>/dev/null)
		installed_version="${installed_version%%-*}"
	fi
	if bashy_install_check "kiro" "${installed_version}" "${latest_version}"
	then
		return
	fi
	local urls
	urls=$(echo "${metadata}" | jq --raw-output --arg v "${latest_version}" \
		'.releases[] | select(.version == $v) | .updateTo.url')
	local download_file certificate_url signature_url
	download_file=$(echo "${urls}" | grep '\.deb$' | head -1)
	certificate_url=$(echo "${urls}" | grep '/certificate\.pem$' | head -1)
	signature_url=$(echo "${urls}" | grep '/signature\.bin$' | head -1)
	if [ -z "${download_file}" ] || [ -z "${certificate_url}" ] || [ -z "${signature_url}" ]
	then
		echo "kiro: the release metadata has no deb, certificate or signature" >&2
		return 1
	fi
	local deb
	bashy_download "${download_file}" deb || return
	# the certificate and signature keep the same names in every release and on
	# every architecture, so they bypass the download cache, which keys on the name
	local tmp_dir
	tmp_dir=$(mktemp --directory)
	if ! curl --fail --silent --location --output "${tmp_dir}/certificate.pem" "${certificate_url}" \
		|| ! curl --fail --silent --location --output "${tmp_dir}/signature.bin" "${signature_url}"
	then
		echo "kiro: could not fetch the certificate or the signature" >&2
		rm -rf "${tmp_dir}"
		return 1
	fi
	if ! _kiro_verify "${deb}" "${tmp_dir}/certificate.pem" "${tmp_dir}/signature.bin"
	then
		rm -rf "${tmp_dir}"
		return 1
	fi
	rm -rf "${tmp_dir}"
	# the deb is already in the cache, so this only revalidates it
	bashy_install_deb "kiro" "${download_file}"
}

# _kiro_verify <deb> <certificate.pem> <signature.bin>
# Succeed when <signature.bin> is Amazon's signature of <deb>. certificate.pem
# holds the leaf followed by its intermediates.
function _kiro_verify() {
	local deb=$1
	local certificate=$2
	local signature=$3
	if ! openssl verify -purpose codesign -untrusted "${certificate}" "${certificate}" > /dev/null
	then
		echo "kiro: the signing certificate does not chain to a trusted CA" >&2
		return 1
	fi
	local subject
	subject=$(openssl x509 -in "${certificate}" -noout -subject)
	if [[ "${subject}" != *"O=Amazon.com, Inc."* ]]
	then
		echo "kiro: the signing certificate is not Amazon's [${subject}]" >&2
		return 1
	fi
	if ! openssl dgst -sha256 -verify <(openssl x509 -in "${certificate}" -noout -pubkey) \
		-signature "${signature}" "${deb}" &> /dev/null
	then
		echo "kiro: signature mismatch for [${deb}]" >&2
		return 1
	fi
	return 0
}

function _uninstall_kiro() {
	bashy_uninstall_apt "kiro" "kiro"
}

register _activate_ai_kiro
register_install _install_kiro
