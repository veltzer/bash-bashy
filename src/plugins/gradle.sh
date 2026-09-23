function _activate_gradle() {
	local -n __var=$1
	local -n __error=$2
	GRADLE_HOME="${HOME}/install/gradle"
	if ! checkDirectoryExists "${GRADLE_HOME}" __var __error; then return; fi
	export GRADLE_HOME
	_bashy_pathutils_add_head PATH "${GRADLE_HOME}/bin"
	__var=0
}

function _install_gradle() {
	# this function installs the latest gradle from a binary zip file distribution
	local latest_version
	latest_version=$(curl --fail --silent --location "https://services.gradle.org/versions/current" | jq --raw-output '.version')
	local toplevel="gradle-${latest_version}"
	local installed_version=""
	if [ -x "${HOME}/install/gradle/bin/gradle" ]
	then
		installed_version=$("${HOME}/install/gradle/bin/gradle" --version 2>/dev/null | awk '/^Gradle /{print $2; exit}')
	fi
	if bashy_install_check "gradle" "${installed_version}" "${latest_version}"
	then
		return
	fi
	local download_file="https://downloads.gradle.org/distributions/${toplevel}-bin.zip"
	bashy_install_download "${download_file}"
	local archive
	bashy_download "${download_file}" archive || return
	bashy_verify_sha256 "${archive}" "${download_file}.sha256" || return
	rm -rf "${HOME}/install/${toplevel}" "${HOME}/install/gradle"
	bashy_install_extract "${archive}" "${HOME}/install"
	ln -sfn "${HOME}/install/${toplevel}" "${HOME}/install/gradle"
}

function _install_gradle_apt() {
	bashy_install_apt "gradle" "gradle"
}
function _uninstall_gradle() {
	# the symlink points at the versioned directory, drop both
	# the symlink points at the versioned directory and may be relative, so
	# resolve it before handing it over to be removed
	local target=""
	if [ -L "${HOME}/install/gradle" ]
	then
		target=$(readlink --canonicalize "${HOME}/install/gradle")
	fi
	bashy_uninstall_directory "gradle" "${HOME}/install/gradle" ${target:+"${target}"}
}

register _activate_gradle
