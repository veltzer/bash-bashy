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

# _prompt_gcp_project_id <configuration name> <out variable>
# The [core] project of the named gcloud configuration, read from its file under
# ${CLOUDSDK_CONFIG:-~/.config/gcloud}/configurations the way "gcloud config
# get-value project" would, with the "read" builtin.
#
# This used to shell out to "pygooglecloud get_project_id", which does exactly
# this file read in python. That tool lives in ~/.venv, and inside a uv project
# prompt_uv has already swapped ~/.venv out for the project's venv by the time a
# second gcp repo is entered, so PROJECT_ID came back empty there. Reading the
# file here depends on nothing and costs no process.
function _prompt_gcp_project_id() {
	local name=$1
	local -n __prompt_gcp_project=$2
	__prompt_gcp_project=""
	local config="${CLOUDSDK_CONFIG:-${HOME}/.config/gcloud}/configurations/config_${name}"
	if [ ! -r "${config}" ]
	then
		return 1
	fi
	local line section=""
	while read -r line || [ -n "${line}" ]
	do
		if [[ "${line}" =~ ^\[([^]]+)\] ]]
		then
			section="${BASH_REMATCH[1]}"
			continue
		fi
		if [ "${section}" = "core" ] && [[ "${line}" =~ ^project[[:space:]]*=[[:space:]]*(.*[^[:space:]])[[:space:]]*$ ]]
		then
			__prompt_gcp_project="${BASH_REMATCH[1]}"
			return 0
		fi
	done < "${config}"
	return 1
}

# runs on every prompt inside a repo that has .gcp.conf, so an edit to it shows
# at the next prompt. Reading the file is builtin "read"; the identity switch
# below has its own guard against redoing work that is already done.
function _prompt_gcp_enter() {
	local conf=$1
	# _prompt_gcp_apply_identity reads this too, through dynamic scoping
	# shellcheck disable=SC2034 # filled and read by name through assoc_*
	local -A gcp_conf=()
	# ~/.gcp.conf supplies defaults, the repo file overrides them
	local home_conf="${HOME}/${gcp_conf_file_name}"
	if [ -r "${home_conf}" ]
	then
		assoc_config_read gcp_conf "${home_conf}"
	fi
	assoc_config_read gcp_conf "${conf}"
	local conf_name=""
	assoc_get gcp_conf conf_name "gcp_configuration_name"

	# Export PROJECT_ID while inside a repo that has a .gcp.conf. This replaces
	# the per-repo .auto.enter.sh/.auto.exit.sh that used to do this.
	if ! var_is_defined PROJECT_ID
	then
		local project=""
		if ! _bashy_null_is_null "${conf_name}" && _prompt_gcp_project_id "${conf_name}" project
		then
			bashy_log "prompt_gcp" "${BASHY_LOG_INFO}" "up"
			export PROJECT_ID="${project}"
		else
			bashy_log "prompt_gcp" "${BASHY_LOG_ERROR}" \
				"no project in gcloud configuration [${conf_name}] named by ${conf}"
		fi
	fi
	# Activate the identity (default account or a named service account)
	# selected by gcp_identity in .gcp.conf.
	_prompt_gcp_apply_identity

	if [ "${CLOUDSDK_ACTIVE_CONFIG_NAME-}" != "${conf_name}" ]
	then
		if var_is_defined CLOUDSDK_ACTIVE_CONFIG_NAME
		then
			bashy_log "prompt_gcp" "${BASHY_LOG_INFO}" "down"
			unset CLOUDSDK_ACTIVE_CONFIG_NAME
		fi
		if ! _bashy_null_is_null "${conf_name}"
		then
			bashy_log "prompt_gcp" "${BASHY_LOG_INFO}" "up"
			export CLOUDSDK_ACTIVE_CONFIG_NAME="${conf_name}"
		fi
	fi
}

function _prompt_gcp_exit() {
	if var_is_defined CLOUDSDK_ACTIVE_CONFIG_NAME
	then
		unset CLOUDSDK_ACTIVE_CONFIG_NAME
	fi
	_prompt_gcp_unset_project_id
	_prompt_gcp_unset_gac
}

# The watching is done by git_prompt_repo_conf in core/git.sh, shared with
# prompt_aws and prompt_k8s. The two functions above say what to do on the way
# in and out.
function prompt_gcp() {
	git_prompt_repo_conf "prompt_gcp" PROMPT_GCP_CONF "${gcp_conf_file_name}" _prompt_gcp_enter _prompt_gcp_exit
}

function _activate_prompt_gcp() {
	local -n __var=$1
	local -n __error=$2
	_bashy_prompt_register prompt_gcp
	__var=0
}

# Undo the activation in the running shell, for bashy_deactivate.
function _deactivate_prompt_gcp() {
	_bashy_prompt_deregister prompt_gcp
	if [ -n "${PROMPT_GCP_CONF-}" ]
	then
		_prompt_gcp_exit "${PROMPT_GCP_CONF}"
		unset PROMPT_GCP_CONF
	fi
}

register_interactive _activate_prompt_gcp _deactivate_prompt_gcp
