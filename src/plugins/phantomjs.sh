function _activate_phantomjs() {
	local -n __var=$1
	local -n __error=$2
	PHANTOMJSPATH="${HOME}/install/phantomjs"
	PHANTOMJSPATHBIN="${PHANTOMJSPATH}/bin"
	if ! checkDirectoryExists "${PHANTOMJSPATH}" __var __error; then return; fi
	if ! checkDirectoryExists "${PHANTOMJSPATHBIN}" __var __error; then return; fi
	_bashy_pathutils_add_head PATH "${PHANTOMJSPATHBIN}"
	export PHANTOMJSPATH
	__var=0
}

function _install_phantomjs() {
	# phantomjs was archived in 2018 with no releases to query, so this is the
	# one installer that legitimately carries a version literal
	local latest_version="2.1.1"
	local toplevel="phantomjs-${latest_version}-linux-x86_64"
	local installed_version=""
	if [ -d "${HOME}/install/${toplevel}" ]
	then
		installed_version="${latest_version}"
	fi
	if bashy_install_check "phantomjs" "${installed_version}" "${latest_version}"
	then
		return
	fi
	local download_file="https://bitbucket.org/ariya/phantomjs/downloads/${toplevel}.tar.bz2"
	bashy_install_download "${download_file}"
	local archive
	bashy_download "${download_file}" archive || return
	rm -rf "${HOME}/install/${toplevel}" "${HOME}/install/phantomjs"
	bashy_install_extract "${archive}" "${HOME}/install"
	ln -sfn "${HOME}/install/${toplevel}" "${HOME}/install/phantomjs"
}
function _uninstall_phantomjs() {
	# the symlink points at the versioned directory and may be relative, so
	# resolve it before handing it over to be removed
	local target=""
	if [ -L "${HOME}/install/phantomjs" ]
	then
		target=$(readlink --canonicalize "${HOME}/install/phantomjs")
	fi
	bashy_uninstall_directory "phantomjs" "${HOME}/install/phantomjs" ${target:+"${target}"}
}

register _activate_phantomjs
