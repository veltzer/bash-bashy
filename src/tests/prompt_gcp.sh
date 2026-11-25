source src/core/assert.sh
source src/core/null.sh
source src/core/misc.sh
source src/core/hooks.sh
source src/core/log.sh
source src/core/var.sh
source src/core/array.sh
source src/core/assoc.sh
source src/core/pathutils.sh
source src/core/git.sh
source src/plugins/prompt.sh
source src/plugins/prompt_gcp.sh

# a gcloud config directory with one configuration, named after its project as
# every configuration is, pointed at by CLOUDSDK_CONFIG
function _test_gcp_config() {
	local -n __dir=$1
	__dir=$(mktemp --directory)
	mkdir -p "${__dir}/configurations"
	cat > "${__dir}/configurations/config_my-project-123" <<'CONF'
[core]
account = someone@example.com
project = my-project-123
CONF
	export CLOUDSDK_CONFIG="${__dir}"
}

function testGcpConfigurationExists() {
	local dir
	_test_gcp_config dir
	_prompt_gcp_configuration_exists my-project-123 || _bashy_assert_fail
	if _prompt_gcp_configuration_exists nosuch
	then
		_bashy_assert_fail
	fi
	rm -rf "${dir}"
}

# a repo with the given .gcp.conf content, entered with prompt_gcp registered
function _test_gcp_enter_repo() {
	local -n __repo=$1
	local content=$2
	__repo=$(mktemp --directory)
	git -c init.defaultBranch=main init --quiet "${__repo}"
	echo "${content}" > "${__repo}/.gcp.conf"
	git_is_inside_flush
	unset PROJECT_ID CLOUDSDK_ACTIVE_CONFIG_NAME PROMPT_GCP_CONF GOOGLE_APPLICATION_CREDENTIALS
	_bashy_array_new _BASHY_PROMPT_FUNCTIONS
	_bashy_prompt_register prompt_gcp
	cd "${__repo}" || _bashy_assert_fail
	prompt_gcp
}

# the plugin end to end: entering a repo with .gcp.conf exports PROJECT_ID and
# activates the configuration of the same name, without any external tool, and
# deactivating clears them
function testPromptGcpExportsProjectAndConfiguration() {
	local dir repo
	_test_gcp_config dir
	_test_gcp_enter_repo repo "gcp_project=my-project-123"
	_bashy_assert_equal "${PROJECT_ID}" "my-project-123"
	_bashy_assert_equal "${CLOUDSDK_ACTIVE_CONFIG_NAME}" "my-project-123"
	_deactivate_prompt_gcp
	if var_is_defined PROJECT_ID || var_is_defined CLOUDSDK_ACTIVE_CONFIG_NAME
	then
		_bashy_assert_fail
	fi
	_bashy_assert_equal "${#_BASHY_PROMPT_FUNCTIONS[@]}" 0
	cd / || _bashy_assert_fail
	rm -rf "${dir}" "${repo}"
}

# a gcp_project with no gcloud configuration of that name activates nothing,
# rather than a configuration gcloud would refuse
function testPromptGcpMissingConfiguration() {
	local dir repo
	_test_gcp_config dir
	_test_gcp_enter_repo repo "gcp_project=nosuch" 2> /dev/null
	if var_is_defined PROJECT_ID || var_is_defined CLOUDSDK_ACTIVE_CONFIG_NAME
	then
		_bashy_assert_fail
	fi
	_deactivate_prompt_gcp
	cd / || _bashy_assert_fail
	rm -rf "${dir}" "${repo}"
}
