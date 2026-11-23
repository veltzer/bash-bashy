# This is a plugin for vnu, the Nu Html Checker: the html validator behind
# validator.w3.org - https://validator.github.io/validator/
#
# It installs two files into the install directory:
# - vnu.jar, the checker itself. rsconstruct's processor.checker.vnu finds it
#   on the path by that name and runs it with java.
# - vnu, a launcher, so that "vnu file.html" works on the command line.
# The checker is a java program, so java has to be on the path to run either.

function _activate_vnu() {
	local -n __var=$1
	local -n __error=$2
	# vnu ships no shell completion, so being on the path is all there is
	if ! checkInPath "vnu" __var __error; then return; fi
	__var=0
}

function _install_vnu() {
	bashy_install_via _install_vnu_tar "$@"
}

function _uninstall_vnu() {
	_uninstall_vnu_tar
}

function _install_vnu_tar() {
	bashy_install_args "$@" || return
	if ! _bashy_pathutils_is_in_path "java"
	then
		echo "vnu: java is not on the path, and vnu is a java program" >&2
		return 1
	fi
	# The jar comes from the npm registry's vnu-jar package rather than from
	# the project's github releases. The project keeps a single release there,
	# tagged "latest", and replaces its assets in place, so the release says
	# neither which version it holds nor when it last changed in a way that
	# can be compared with what is installed. The registry gives a version, a
	# permanent url for it and a digest. The package is the jar and a node
	# launcher that is not used, so node is not needed.
	local package_json
	if ! bashy_fetch_latest "https://registry.npmjs.org/vnu-jar/latest" package_json
	then
		echo "vnu: could not fetch the package description" >&2
		return 1
	fi
	local latest_version
	latest_version=$(echo "${package_json}" | jq --raw-output '.version')
	local folder
	folder=$(bashy_install_dir)
	local jar="${folder}/vnu.jar"
	local launcher="${folder}/vnu"
	local installed_version=""
	if [[ -f "${jar}" ]]
	then
		# vnu --version prints "26.11.14 (7a9e046)"
		installed_version=$({ java -jar "${jar}" --version 2>/dev/null || true; } | awk '{print $1; exit}')
	fi
	if bashy_install_check "vnu" "${installed_version}" "${latest_version}"
	then
		return
	fi
	local download_file
	download_file=$(echo "${package_json}" | jq --raw-output '.dist.tarball')
	bashy_install_download "${download_file}"
	local tar
	bashy_download "${download_file}" tar || return
	# the registry publishes a sha512 in base64 ("sha512-<base64>"), not the
	# sha256 that bashy_verify_sha256 checks, so it is compared here
	local expected
	expected=$(echo "${package_json}" | jq --raw-output '.dist.integrity')
	local actual
	actual="sha512-$({ openssl dgst -sha512 -binary "${tar}" || true; } | base64 --wrap=0)"
	if [[ "${expected}" != "${actual}" ]]
	then
		echo "vnu: the download does not match the digest the registry published" >&2
		echo "vnu: expected [${expected}], got [${actual}]" >&2
		return 1
	fi
	rm -f "${jar}" "${launcher}"
	# the tarball holds the jar three directories down
	bashy_install_extract "${tar}" "${folder}" "package/build/dist/vnu.jar" --strip-components=3 || return
	# executable, so that the path lookup rsconstruct does finds it
	chmod +x "${jar}"
	# the launcher finds the jar beside itself, wherever the two are installed
	cat > "${launcher}" <<-'EOF'
		#!/bin/sh
		exec java -jar "$(dirname "$0")/vnu.jar" "$@"
	EOF
	chmod +x "${launcher}"
}

function _uninstall_vnu_tar() {
	bashy_uninstall_binary "vnu.jar"
	bashy_uninstall_binary "vnu"
}

register_interactive _activate_vnu
register_install _install_vnu
