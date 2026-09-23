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
# straight into a shell.
function _install_google_cloud_sdk() {
	export CLOUDSDK_CORE_DISABLE_PROMPTS=1
	export CLOUDSDK_INSTALL_DIR="${HOME}/install"
	echo "Installing google-cloud-sdk via the vendor install script"
	local script
	bashy_download "https://sdk.cloud.google.com" script || return
	echo "running [${script}], inspect it first if you like"
	bash "${script}"
	gcloud auth login
	gcloud components update
}

function _uninstall_google_cloud_sdk() {
	bashy_uninstall_directory "google-cloud-sdk" "${HOME}/install/google-cloud-sdk"
}

function _bashy_gcloud_update() {
	gcloud components update
}

register_interactive _activate_google_cloud_sdk
