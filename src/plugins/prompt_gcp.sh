# This script manages your google clound environment for you.
# Whenever you 'cd' into a git folder that has .gcp.conf in it
# it will activate the right google cloud project for you.

gcp_conf_file_name=".gcp.conf"

# Unset PROJECT_ID if it is currently set, logging the transition.
function _prompt_gcp_unset_project_id() {
	if var_is_defined PROJECT_ID
	then
		bashy_log "prompt_gcp" "${BASHY_LOG_INFO}" "down"
		unset PROJECT_ID
	fi
}

# Tracks the decrypted temp key file the plugin created, so it can be shredded
# when the identity is deactivated. Empty means no temp file is live.
_PROMPT_GCP_KEY_TMPFILE=""

# Deactivate the service-account identity: shred the decrypted temp key file
# (if any) and unset GOOGLE_APPLICATION_CREDENTIALS. This is the "run as the
# default (personal) account" state.
function _prompt_gcp_unset_gac() {
	if [ -n "${_PROMPT_GCP_KEY_TMPFILE}" ]
	then
		shred -u "${_PROMPT_GCP_KEY_TMPFILE}" 2>/dev/null
		_PROMPT_GCP_KEY_TMPFILE=""
	fi
	if var_is_defined GOOGLE_APPLICATION_CREDENTIALS
	then
		bashy_log "prompt_gcp" "${BASHY_LOG_INFO}" "down"
		unset GOOGLE_APPLICATION_CREDENTIALS
	fi
}

# Activate the identity named by gcp_identity (read into the gcp_conf assoc).
#
#   unset/empty/"default" -> default (personal) account, no GOOGLE_APPLICATION_CREDENTIALS.
#   <name>                -> service account whose key is stored in pass(1) at
#                            the path given by "gcp_sa_<name>". The key is
#                            decrypted to a temp file under XDG_RUNTIME_DIR and
#                            GOOGLE_APPLICATION_CREDENTIALS points at it.
#
# Every error is hard and fail-closed: on a missing gcp_sa_<name> entry or a
# pass entry that cannot be read, log an error and fall back to the default
# account (no credentials) rather than activate a broken identity.
function _prompt_gcp_apply_identity() {
	local gcp_identity=""
	assoc_get gcp_conf gcp_identity "gcp_identity"

	if _bashy_null_is_null "${gcp_identity}" || [ "${gcp_identity}" = "default" ]
	then
		_prompt_gcp_unset_gac
		return
	fi

	local pass_path=""
	assoc_get gcp_conf pass_path "gcp_sa_${gcp_identity}"
	if _bashy_null_is_null "${pass_path}"
	then
		bashy_log "prompt_gcp" "${BASHY_LOG_ERROR}" \
			"no 'gcp_sa_${gcp_identity}' entry in .gcp.conf for identity '${gcp_identity}'"
		_prompt_gcp_unset_gac
		return
	fi

	# The config is read verbatim, so expand ${PROJECT_ID}, etc. in the path.
	eval "pass_path=\"${pass_path}\""

	# Already active for this identity: nothing to do (avoid re-decrypting on
	# every prompt). We tag the live temp file's identity via a sibling marker
	# in the variable name's value space using the pass path as the key.
	if [ -n "${_PROMPT_GCP_KEY_TMPFILE}" ] && \
		[ "${GOOGLE_APPLICATION_CREDENTIALS}" = "${_PROMPT_GCP_KEY_TMPFILE}" ] && \
		[ "${_PROMPT_GCP_KEY_PASS_PATH}" = "${pass_path}" ]
	then
		return
	fi

	# Decrypt the key out of pass. Hard-fail if the entry is missing/unreadable.
	local key_data=""
	if ! key_data="$(pass show "${pass_path}" 2>/dev/null)" || _bashy_null_is_null "${key_data}"
	then
		bashy_log "prompt_gcp" "${BASHY_LOG_ERROR}" \
			"cannot read service-account key from pass at '${pass_path}' for identity '${gcp_identity}'"
		_prompt_gcp_unset_gac
		return
	fi

	# Shred any previously-active temp key before creating a new one.
	if [ -n "${_PROMPT_GCP_KEY_TMPFILE}" ]
	then
		shred -u "${_PROMPT_GCP_KEY_TMPFILE}" 2>/dev/null
		_PROMPT_GCP_KEY_TMPFILE=""
	fi

	local runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
	local tmpfile=""
	tmpfile="$(mktemp "${runtime_dir}/gcp-sa.XXXXXX")"
	chmod 600 "${tmpfile}"
	printf '%s' "${key_data}" > "${tmpfile}"

	_PROMPT_GCP_KEY_TMPFILE="${tmpfile}"
	_PROMPT_GCP_KEY_PASS_PATH="${pass_path}"
	bashy_log "prompt_gcp" "${BASHY_LOG_INFO}" "up"
	export GOOGLE_APPLICATION_CREDENTIALS="${tmpfile}"
}

function prompt_gcp() {
	# _prompt_gcp_apply_identity reads this too, through dynamic scoping
	# shellcheck disable=SC2034 # filled and read by name through assoc_*
	local -A gcp_conf=()
	local git_root gcp_home_conf_file CLOUDSDK_ACTIVE_CONFIG_NAME_NEW

	if ! git_is_inside
	then
		if var_is_defined CLOUDSDK_ACTIVE_CONFIG_NAME
		then
			bashy_log "prompt_gcp" "${BASHY_LOG_INFO}" "down"
			unset CLOUDSDK_ACTIVE_CONFIG_NAME
		fi
		_prompt_gcp_unset_project_id
		_prompt_gcp_unset_gac
		return
	fi

	git_root=""
	git_top_level git_root

	gcp_home_conf_file="${HOME}/${gcp_conf_file_name}"
	if [ -r "${gcp_home_conf_file}" ]
	then
		assoc_config_read gcp_conf "${gcp_home_conf_file}"
	fi

	if [ -r "${git_root}/${gcp_conf_file_name}" ]
	then
		assoc_config_read gcp_conf "${git_root}/${gcp_conf_file_name}"
	fi

	# Export PROJECT_ID while inside a repo that has a .gcp.conf, and unset it
	# otherwise. This replaces the per-repo .auto.enter.sh/.auto.exit.sh that
	# used to do this.
	if [ -r "${git_root}/${gcp_conf_file_name}" ]
	then
		if ! var_is_defined PROJECT_ID
		then
			bashy_log "prompt_gcp" "${BASHY_LOG_INFO}" "up"
			export PROJECT_ID
			PROJECT_ID="$(pygooglecloud get_project_id)"
		fi
		# Activate the identity (default account or a named service account)
		# selected by gcp_identity in .gcp.conf.
		_prompt_gcp_apply_identity
	else
		_prompt_gcp_unset_project_id
		_prompt_gcp_unset_gac
	fi

	CLOUDSDK_ACTIVE_CONFIG_NAME_NEW=""
	assoc_get gcp_conf CLOUDSDK_ACTIVE_CONFIG_NAME_NEW "gcp_configuration_name"
	if [ "${CLOUDSDK_ACTIVE_CONFIG_NAME}" != "${CLOUDSDK_ACTIVE_CONFIG_NAME_NEW}" ]
	then
		if var_is_defined CLOUDSDK_ACTIVE_CONFIG_NAME
		then
			bashy_log "prompt_gcp" "${BASHY_LOG_INFO}" "down"
			unset CLOUDSDK_ACTIVE_CONFIG_NAME
		fi
		if ! _bashy_null_is_null "${CLOUDSDK_ACTIVE_CONFIG_NAME_NEW}"
		then
			bashy_log "prompt_gcp" "${BASHY_LOG_INFO}" "up"
			export CLOUDSDK_ACTIVE_CONFIG_NAME="${CLOUDSDK_ACTIVE_CONFIG_NAME_NEW}"
		fi
	fi
}

function _activate_prompt_gcp() {
	local -n __var=$1
	local -n __error=$2
	_bashy_prompt_register prompt_gcp
	__var=0
}

register_interactive _activate_prompt_gcp
