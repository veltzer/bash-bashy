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

# a gcloud config directory with one configuration, pointed at by CLOUDSDK_CONFIG
function _test_gcp_config() {
	local -n __dir=$1
	__dir=$(mktemp --directory)
	mkdir -p "${__dir}/configurations"
	cat > "${__dir}/configurations/config_unit" <<'CONF'
[core]
account = someone@example.com
project = my-project-123

[compute]
project = not-this-one
CONF
	export CLOUDSDK_CONFIG="${__dir}"
}

function testGcpProjectIdFromCoreSection() {
	local dir project=""
	_test_gcp_config dir
	_prompt_gcp_project_id unit project || _bashy_assert_fail
	# the [compute] section has a project too; only [core] counts
	_bashy_assert_equal "${project}" "my-project-123"
	rm -rf "${dir}"
}

function testGcpProjectIdMissingConfiguration() {
	local dir project="x"
	_test_gcp_config dir
	if _prompt_gcp_project_id nosuch project
	then
		_bashy_assert_fail
	fi
	_bashy_assert_equal "${project}" ""
	rm -rf "${dir}"
}

function testGcpProjectIdNoProjectLine() {
	local dir project="x"
	_test_gcp_config dir
	printf '[core]\naccount = a\n' > "${dir}/configurations/config_bare"
	if _prompt_gcp_project_id bare project
	then
		_bashy_assert_fail
	fi
	rm -rf "${dir}"
}

# the plugin end to end: entering a repo with .gcp.conf exports PROJECT_ID and the
# configuration name, without any external tool, and deactivating clears them
function testPromptGcpExportsProjectAndConfiguration() {
	local dir repo
	_test_gcp_config dir
	repo=$(mktemp --directory)
	git -c init.defaultBranch=main init --quiet "${repo}"
	echo "gcp_configuration_name=unit" > "${repo}/.gcp.conf"
	git_is_inside_flush
	unset PROJECT_ID CLOUDSDK_ACTIVE_CONFIG_NAME PROMPT_GCP_CONF GOOGLE_APPLICATION_CREDENTIALS
	_bashy_array_new _BASHY_PROMPT_FUNCTIONS
	_bashy_prompt_register prompt_gcp
	cd "${repo}" || _bashy_assert_fail
	prompt_gcp
	_bashy_assert_equal "${PROJECT_ID}" "my-project-123"
	_bashy_assert_equal "${CLOUDSDK_ACTIVE_CONFIG_NAME}" "unit"
	_deactivate_prompt_gcp
	if var_is_defined PROJECT_ID || var_is_defined CLOUDSDK_ACTIVE_CONFIG_NAME
	then
		_bashy_assert_fail
	fi
	_bashy_assert_equal "${#_BASHY_PROMPT_FUNCTIONS[@]}" 0
	cd / || _bashy_assert_fail
	rm -rf "${dir}" "${repo}"
}
