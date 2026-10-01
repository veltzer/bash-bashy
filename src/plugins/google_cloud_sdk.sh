function _activate_google_cloud_sdk() {
	local -n __var=$1
	local -n __error=$2
	GOOGLE_CLOUD_HOME="${HOME}/install/google-cloud-sdk"
	if ! checkDirectoryExists "${GOOGLE_CLOUD_HOME}" __var __error; then return; fi
	export GOOGLE_CLOUD_HOME
	# shellcheck source=/dev/null
	if ! source "${GOOGLE_CLOUD_HOME}/path.bash.inc"
	then
		__var=$?
		__error="could not source google cloud path"
		return
	fi
	# shellcheck source=/dev/null
	if ! source "${GOOGLE_CLOUD_HOME}/completion.bash.inc"
	then
		__var=$?
		__error="could not source google cloud bash completion"
		return
	fi
	__var=0
}

# The vendor installer is a shell script with no release asset to download and
# verify instead, so it is fetched first and then run from disk rather than piped
# straight into a shell. It only runs for a fresh install: once the sdk is in
# place, moving it forward is the job of its own component manager.
function _install_google_cloud_sdk() {
	export CLOUDSDK_CORE_DISABLE_PROMPTS=1
	export CLOUDSDK_INSTALL_DIR="${HOME}/install"
	local folder="${CLOUDSDK_INSTALL_DIR}/google-cloud-sdk"
	local latest_version
	# the component manifest of the rapid channel is what gcloud itself consults
	# to find out whether it is current, so ask the same source
	latest_version=$(curl --fail --silent --location \
		"https://dl.google.com/dl/cloudsdk/channels/rapid/components-2.json" \
		| jq --raw-output '.version')
	local installed_version=""
	# the sdk records its version in a plain file, which is cheaper than starting
	# a python interpreter to ask gcloud
	if [ -f "${folder}/VERSION" ]
	then
		installed_version=$(tr -d '[:space:]' < "${folder}/VERSION")
	fi
	if bashy_install_check "google-cloud-sdk" "${installed_version}" "${latest_version}"
	then
		return
	fi
	if [ -n "${installed_version}" ]
	then
		"${folder}/bin/gcloud" components update
		return
	fi
	echo "Installing google-cloud-sdk via the vendor install script"
	local script
	bashy_download "https://sdk.cloud.google.com" script || return
	echo "running [${script}], inspect it first if you like"
	bash "${script}" || return
	"${folder}/bin/gcloud" auth login
	"${folder}/bin/gcloud" components update
}

function _uninstall_google_cloud_sdk() {
	bashy_uninstall_directory "google-cloud-sdk" "${HOME}/install/google-cloud-sdk"
}

function _bashy_gcloud_update() {
	gcloud components update
}

# Undo the activation in the running shell, for bashy_deactivate.
function _deactivate_google_cloud_sdk() {
	_bashy_pathutils_remove PATH "${HOME}/install/google-cloud-sdk/bin"
	complete -r gcloud gsutil bq 2> /dev/null
	unset GOOGLE_CLOUD_HOME
}

register_interactive _activate_google_cloud_sdk _deactivate_google_cloud_sdk
register_install _install_google_cloud_sdk
