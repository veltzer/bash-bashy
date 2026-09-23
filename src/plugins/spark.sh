# This is a plugin for spark

function _activate_spark() {
	local -n __var=$1
	local -n __error=$2
	SPARK_HOME="${HOME}/install/spark"
	local SPARK_BIN="${SPARK_HOME}/bin"
	if ! checkDirectoryExists "${SPARK_HOME}" __var __error; then return; fi
	if ! checkDirectoryExists "${SPARK_BIN}" __var __error; then return; fi
	_bashy_pathutils_add_head PATH "${SPARK_BIN}"
	export SPARK_HOME
	__var=0
}

function _install_spark() {
	# instructions for installing spark are at
	# https://medium.com/@patilmailbox4/install-apache-spark-on-ubuntu-ffa151e12e30
	# the download mirror lists a directory per release, take the highest one
	local latest_version
	latest_version=$(curl --fail --silent --location "https://dlcdn.apache.org/spark/" | grep -oP 'href="spark-\K[0-9]+\.[0-9]+\.[0-9]+(?=/")' | sort --version-sort --unique | tail -1)
	local toplevel="spark-${latest_version}-bin-hadoop3"
	# ~/install/spark is a symlink into the versioned directory, so it names what is installed
	local installed_version=""
	if [ -L "${HOME}/install/spark" ]
	then
		installed_version=$(readlink "${HOME}/install/spark" | grep -oP 'spark-\K[0-9]+\.[0-9]+\.[0-9]+')
	fi
	if bashy_install_check "spark" "${installed_version}" "${latest_version}"
	then
		return
	fi
	local download_file="https://dlcdn.apache.org/spark/spark-${latest_version}/${toplevel}.tgz"
	bashy_install_download "${download_file}"
	local archive
	bashy_download "${download_file}" archive || return
	# apache publishes a sha512 rather than a sha256 next to the archive, and
	# bashy_verify_sha256 only speaks sha256, so there is nothing to verify here
	# drop the previous install, otherwise every upgrade leaves the old tree behind
	if [ -n "${installed_version}" ]
	then
		rm -rf "${HOME}/install/spark-${installed_version}-bin-hadoop3"
	fi
	rm -rf "${HOME}/install/spark" "${HOME}/install/${toplevel}"
	bashy_install_extract "${archive}" "${HOME}/install"
	ln -sfn "${HOME}/install/${toplevel}" "${HOME}/install/spark"
}

function _uninstall_spark() {
	# the symlink points at the versioned directory and may be relative, so
	# resolve it before handing it over to be removed
	local target=""
	if [ -L "${HOME}/install/spark" ]
	then
		target=$(readlink --canonicalize "${HOME}/install/spark")
	fi
	bashy_uninstall_directory "spark" "${HOME}/install/spark" ${target:+"${target}"}
}

register _activate_spark
