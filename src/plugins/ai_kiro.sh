# This is integration of kiro, the AWS agentic IDE built on Code OSS
# https://kiro.dev

function _activate_ai_kiro() {
	local -n __var=$1
	local -n __error=$2
	__var=0
}

# Kiro ships two linux packages, a deb and a tarball, and nothing else (no rpm,
# AppImage, snap or flatpak). Kiro's updater reads a per platform json naming the
# current release and three files beside it: the package, a certificate.pem and a
# signature.bin. There is no sha256 to hand bashy_verify_sha256, so the package
# is checked the way kiro checks it: the certificate has to chain to a CA the
# system trusts for code signing and name Amazon as its owner, and the signature
# has to verify against its key.
#
#	_install_kiro_deb	the deb, system wide in /usr/share/kiro
#	_install_kiro_tar	the tarball, for one user in ~/install/kiro, no apt
#
# _install_kiro picks the deb where dpkg is there to own it and the tarball
# everywhere else, and _uninstall_kiro follows the same choice.

# Where _install_kiro_tar unpacks to, and the AppArmor profile it needs there.
KIRO_TAR_FOLDER="${HOME}/install/kiro"
KIRO_TAR_APPARMOR="/etc/apparmor.d/kiro-${USER}"

# _kiro_arch
# Echo the architecture name kiro uses in its urls.
function _kiro_arch() {
	case "$(uname -m)" in
		x86_64|amd64) echo "x64" ;;
		arm64|aarch64) echo "arm64" ;;
		*)
			echo "kiro: unsupported architecture [$(uname -m)]" >&2
			return 1
			;;
	esac
}

# _kiro_metadata <deb|tar> <out_var>
# Fetch the release metadata of one of the two packages. The tarball's file is
# the one without a package name in it.
function _kiro_metadata() {
	local package=$1
	local -n __metadata=$2
	local arch
	arch=$(_kiro_arch) || return
	local name="metadata-linux-${arch}-stable.json"
	if [ "${package}" = "deb" ]
	then
		name="metadata-linux-${arch}-deb-stable.json"
	fi
	if ! bashy_fetch_latest "https://prod.download.desktop.kiro.dev/stable/${name}" __metadata
	then
		echo "kiro: could not fetch the release metadata" >&2
		return 1
	fi
}

# _kiro_download <metadata> <version> <package regex> <out_var>
# Download the package of <version> named in <metadata> through the cache,
# check its signature and assign the path of the cached file to <out_var>.
function _kiro_download() {
	local metadata=$1
	local version=$2
	local pattern=$3
	local -n __file=$4
	local urls
	urls=$(echo "${metadata}" | jq --raw-output --arg v "${version}" \
		'.releases[] | select(.version == $v) | .updateTo.url')
	local download_file certificate_url signature_url
	download_file=$(echo "${urls}" | grep "${pattern}" | head -1)
	certificate_url=$(echo "${urls}" | grep '/certificate\.pem$' | head -1)
	signature_url=$(echo "${urls}" | grep '/signature\.bin$' | head -1)
	if [ -z "${download_file}" ] || [ -z "${certificate_url}" ] || [ -z "${signature_url}" ]
	then
		echo "kiro: the release metadata has no package, certificate or signature" >&2
		return 1
	fi
	bashy_install_download "${download_file}"
	bashy_download "${download_file}" __file || return
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
	if ! _kiro_verify "${__file}" "${tmp_dir}/certificate.pem" "${tmp_dir}/signature.bin"
	then
		rm -rf "${tmp_dir}"
		return 1
	fi
	rm -rf "${tmp_dir}"
}

# _kiro_verify <package> <certificate.pem> <signature.bin>
# Succeed when <signature.bin> is Amazon's signature of <package>.
# certificate.pem holds the leaf followed by its intermediates.
function _kiro_verify() {
	local package=$1
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
		-signature "${signature}" "${package}" &> /dev/null
	then
		echo "kiro: signature mismatch for [${package}]" >&2
		return 1
	fi
	return 0
}

function _install_kiro() {
	# the deb is the vendor's own linux install and the one the package manager
	# owns afterwards; the tarball is for systems without dpkg
	if _bashy_pathutils_is_in_path "dpkg"
	then
		bashy_install_via _install_kiro_deb "$@"
	else
		bashy_install_via _install_kiro_tar "$@"
	fi
}

function _uninstall_kiro() {
	if _bashy_pathutils_is_in_path "dpkg"
	then
		_uninstall_kiro_deb
	else
		_uninstall_kiro_tar
	fi
}

# Install the latest kiro IDE from its signed deb package.
# https://kiro.dev/downloads/
function _install_kiro_deb() {
	bashy_install_args "$@" || return
	local metadata
	_kiro_metadata "deb" metadata || return
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
	local deb
	_kiro_download "${metadata}" "${latest_version}" '\.deb$' deb || return
	# not bashy_install_deb, which fetches the url again: dpkg gets the very file
	# whose signature was just checked
	echo "Installing kiro from a deb package"
	sudo dpkg --install "${deb}" || sudo apt-get install --fix-broken --assume-yes
}

function _uninstall_kiro_deb() {
	bashy_uninstall_apt "kiro" "kiro"
}

# Install the latest kiro IDE from its signed tarball into ~/install/kiro, with
# a kiro command in BASHY_INSTALL_DIR and desktop entries in ~/.local/share.
# The tarball holds the same tree the deb puts in /usr/share/kiro, but none of
# the integration the deb's postinst adds, so this adds the parts kiro needs:
# - the desktop entries, the url handler one included, since signing in to kiro
#   returns to it through a kiro:// url
# - on systems that restrict unprivileged user namespaces (Ubuntu 24.04 and
#   later) an AppArmor profile letting kiro create them, without which Chromium's
#   sandbox aborts at start. It is the profile the deb installs, aimed at this
#   folder, and it is the one step that needs sudo.
function _install_kiro_tar() {
	bashy_install_args "$@" || return
	local metadata
	_kiro_metadata "tar" metadata || return
	local latest_version
	latest_version=$(echo "${metadata}" | jq --raw-output '.currentRelease // empty')
	local folder="${KIRO_TAR_FOLDER}"
	local installed_version=""
	if [ -x "${folder}/kiro" ] && [ -f "${folder}/resources/app/product.json" ]
	then
		installed_version=$(jq --raw-output '.version // empty' "${folder}/resources/app/product.json")
	fi
	if bashy_install_check "kiro" "${installed_version}" "${latest_version}"
	then
		return
	fi
	local tar
	_kiro_download "${metadata}" "${latest_version}" '\.tar\.gz$' tar || return
	rm -rf "${folder}"
	mkdir -p "${folder}"
	# the tarball's single top level folder is "Kiro"
	bashy_install_extract "${tar}" "${folder}" --strip-components=1 || return
	# bin/kiro follows its symlink to find the app beside it
	local executable
	executable="$(bashy_install_dir)/kiro"
	ln --symbolic --force "${folder}/bin/kiro" "${executable}"
	_kiro_tar_desktop "${folder}"
	_kiro_tar_apparmor "${folder}"
}

# _kiro_tar_desktop <folder>
# Write the desktop entries the deb ships, pointed at <folder>. Under the deb's
# file names they take precedence over the deb's own while both are installed.
function _kiro_tar_desktop() {
	local folder=$1
	local applications="${HOME}/.local/share/applications"
	mkdir -p "${applications}"
	local icon="${folder}/resources/app/resources/linux/code.png"
	cat > "${applications}/kiro.desktop" << EOF
[Desktop Entry]
Name=Kiro
Comment=Alongside you from concept to production.
GenericName=Text Editor
Exec=${folder}/kiro %F
Icon=${icon}
Type=Application
StartupNotify=false
StartupWMClass=Kiro
Categories=TextEditor;Development;IDE;AI;
MimeType=application/x-kiro-workspace;
Actions=new-empty-window;
Keywords=kiro;

[Desktop Action new-empty-window]
Name=New Empty Window
Exec=${folder}/kiro --new-window %F
Icon=${icon}
EOF
	cat > "${applications}/kiro-url-handler.desktop" << EOF
[Desktop Entry]
Name=Kiro - URL Handler
Comment=Alongside you from concept to production.
GenericName=Kiro
Exec=${folder}/kiro --open-url %U
Icon=${icon}
Type=Application
NoDisplay=true
StartupNotify=true
Categories=Utility;TextEditor;Development;IDE;
MimeType=x-scheme-handler/kiro;
Keywords=kiro;
EOF
	if _bashy_pathutils_is_in_path "update-desktop-database"
	then
		update-desktop-database "${applications}"
	fi
	if _bashy_pathutils_is_in_path "xdg-mime"
	then
		xdg-mime default "kiro-url-handler.desktop" "x-scheme-handler/kiro"
	fi
}

# _kiro_tar_apparmor <folder>
# Let <folder>/kiro create user namespaces where the kernel restricts them.
# The profile is named per user, so it never collides with the deb's
# /etc/apparmor.d/kiro or with another user's tarball install.
function _kiro_tar_apparmor() {
	local folder=$1
	local restrict="/proc/sys/kernel/apparmor_restrict_unprivileged_userns"
	if [ ! -f "${restrict}" ] || [ "$(cat "${restrict}")" != "1" ]
	then
		return 0
	fi
	echo "writing ${KIRO_TAR_APPARMOR} so that kiro's sandbox can start"
	sudo tee "${KIRO_TAR_APPARMOR}" > /dev/null << EOF
# Written by bashy's _install_kiro_tar and removed by _uninstall_kiro_tar.
# It lets the tarball install of Kiro create unprivileged user namespaces, which
# Chromium's sandbox needs. It does not confine the app. It is the profile the
# kiro deb installs as /etc/apparmor.d/kiro, for a different path.
abi <abi/4.0>,
include <tunables/global>

profile kiro-${USER} ${folder}/kiro flags=(unconfined) {
  userns,
}
EOF
	sudo apparmor_parser --replace "${KIRO_TAR_APPARMOR}"
}

function _uninstall_kiro_tar() {
	local executable="${BASHY_INSTALL_DIR}/kiro"
	if [ -L "${executable}" ]
	then
		echo "removing ${executable}"
		rm -f "${executable}"
	fi
	bashy_uninstall_directory "kiro" "${KIRO_TAR_FOLDER}"
	local applications="${HOME}/.local/share/applications"
	bashy_uninstall_binary "kiro.desktop" "${applications}/kiro.desktop"
	bashy_uninstall_binary "kiro-url-handler.desktop" "${applications}/kiro-url-handler.desktop"
	if [ -f "${KIRO_TAR_APPARMOR}" ]
	then
		echo "removing ${KIRO_TAR_APPARMOR}"
		sudo apparmor_parser --remove "${KIRO_TAR_APPARMOR}"
		sudo rm -f "${KIRO_TAR_APPARMOR}"
	else
		echo "no ${KIRO_TAR_APPARMOR} detected"
	fi
}

register _activate_ai_kiro
register_install _install_kiro
