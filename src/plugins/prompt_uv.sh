# This plugin manages a uv(1) based python virtual environment for you.
#
# Here is what it does:
# - Whenever you 'cd' into a folder that has a 'pyproject.toml' file
# (or into any folder below it) the projects '.venv' is activated
# for you.
# - If the checksum of 'pyproject.toml' differs from the checksum
# stored in '.venv/pyproject.toml.checksum' (which also covers the
# case of a venv that was never created) then 'uv sync' is run and
# the new checksum is stored.
# - Any virtual env that was active before is deactivated and put on
# hold; it is re-activated once you leave the project folder.
# - If '.venv' is missing entirely (say a 'git clean' took it) that
# same 'uv sync' recreates it, and a leftover '.uv.sync.errors' from
# before the venv vanished does not block that sync.
# - If 'uv sync' fails its output is kept in '.uv.sync.errors' at the
# project root and no further syncs happen until that file is removed.
# The file is erased automatically once the venv is found to be in
# sync again (a later sync succeeds, or pyproject.toml is reverted to
# what the venv was built from).

export _BASHY_UV_ACTIVE=""
export _BASHY_UV_HELD=""
export _BASHY_UV_BIN=""

# find the closest folder at or above ${PWD} holding a pyproject.toml
function _prompt_uv_find_root() {
	local -n __root=$1
	local dir="${PWD}"
	while true
	do
		if [ -f "${dir}/pyproject.toml" ]
		then
			__root="${dir}"
			return 0
		fi
		if [ "${dir}" == "/" ]
		then
			return 1
		fi
		# one step up, in the shell: dirname(1) was four forks on every prompt
		dir="${dir%/*}"
		dir="${dir:-/}"
	done
}

function _prompt_uv_sync() {
	local project_root=$1
	local venv=$2
	local checksum_file="${venv}/pyproject.toml.checksum"
	local error_file="${project_root}/.uv.sync.errors"
	local current
	current=$(md5sum < "${project_root}/pyproject.toml")
	local stored=""
	if [ -r "${checksum_file}" ]
	then
		stored=$(cat "${checksum_file}")
	fi
	if [ "${current}" == "${stored}" ]
	then
		bashy_log "prompt_uv" "${BASHY_LOG_DEBUG}" "checksum is up to date"
		# the venv is in sync, so a sentinel left by an earlier failure is stale
		if [ -f "${error_file}" ]
		then
			bashy_log "prompt_uv" "${BASHY_LOG_INFO}" "venv is in sync, removing stale error file [${error_file}]"
			rm -f "${error_file}"
		fi
		return 0
	fi
	if [ -f "${error_file}" ]
	then
		if [ -d "${venv}" ]
		then
			bashy_log "prompt_uv" "${BASHY_LOG_ERROR}" "found error file [${error_file}], not syncing"
			return 1
		fi
		# no venv at all (a 'git clean' took it): whatever failed back
		# then happened to a venv that no longer exists, so start over
		bashy_log "prompt_uv" "${BASHY_LOG_INFO}" "venv is gone, removing error file [${error_file}] and re-syncing"
		rm -f "${error_file}"
	fi
	bashy_log "prompt_uv" "${BASHY_LOG_INFO}" "running uv sync in [${project_root}]"
	# ${_BASHY_UV_BIN} rather than plain uv: uv may live in the very env this
	# plugin put on hold, which is off the PATH while a project env is active,
	# and a re-sync after '.venv' was deleted under us would then find no uv
	if (cd "${project_root}" || exit 1; "${_BASHY_UV_BIN}" sync > "${error_file}" 2>&1)
	then
		rm -f "${error_file}"
		echo "${current}" > "${checksum_file}"
		return 0
	fi
	bashy_log "prompt_uv" "${BASHY_LOG_ERROR}" "uv sync failed, see [${error_file}]"
	return 1
}

# leave the active project venv, if any, and give back the env that was held
# while it was active. Shared by the prompt (on leaving the project) and the
# deactivate function.
function _prompt_uv_leave() {
	if [ -z "${_BASHY_UV_ACTIVE}" ]
	then
		return
	fi
	bashy_log "prompt_uv" "${BASHY_LOG_INFO}" "left project, deactivating [${_BASHY_UV_ACTIVE}]"
	python_deactivate
	_BASHY_UV_ACTIVE=""
	if [ -n "${_BASHY_UV_HELD}" ]
	then
		bashy_log "prompt_uv" "${BASHY_LOG_INFO}" "restoring held env [${_BASHY_UV_HELD}]"
		python_activate "${_BASHY_UV_HELD}"
		_BASHY_UV_HELD=""
	fi
}

function prompt_uv() {
	local project_root=""
	if ! _prompt_uv_find_root project_root
	then
		_prompt_uv_leave
		return
	fi
	local venv="${project_root}/.venv"
	if [ -n "${_BASHY_UV_ACTIVE}" ] && [ "${_BASHY_UV_ACTIVE}" != "${venv}" ]
	then
		# moved straight into another project - the held env stays held
		bashy_log "prompt_uv" "${BASHY_LOG_INFO}" "switching from [${_BASHY_UV_ACTIVE}] to [${venv}]"
		python_deactivate
		_BASHY_UV_ACTIVE=""
	fi
	if ! _prompt_uv_sync "${project_root}" "${venv}"
	then
		return
	fi
	if [ -z "${_BASHY_UV_ACTIVE}" ]
	then
		if var_is_defined PYTHON_VENV_ACTIVE
		then
			bashy_log "prompt_uv" "${BASHY_LOG_INFO}" "holding env [${PYTHON_VENV_ACTIVE}]"
			_BASHY_UV_HELD="${PYTHON_VENV_ACTIVE}"
			python_deactivate
		elif var_is_defined VIRTUAL_ENV
		then
			# a virtual env activated with "source .../bin/activate".
			# do not call its own "deactivate": that restores the PATH
			# snapshot taken at activation time, wiping every entry added
			# since (the node plugin's bin folder among them). take the
			# venv off the PATH ourselves instead.
			bashy_log "prompt_uv" "${BASHY_LOG_INFO}" "holding env [${VIRTUAL_ENV}]"
			_BASHY_UV_HELD="${VIRTUAL_ENV}"
			_bashy_pathutils_remove PATH "${VIRTUAL_ENV}/bin"
			unset VIRTUAL_ENV VIRTUAL_ENV_PROMPT _OLD_VIRTUAL_PATH _OLD_VIRTUAL_PS1
			unset -f deactivate
		fi
		python_activate "${venv}"
		_BASHY_UV_ACTIVE="${venv}"
	fi
}

function _activate_prompt_uv() {
	local -n __var=$1
	local -n __error=$2
	if ! checkInPath "uv" __var __error; then return; fi
	if ! checkInPath "md5sum" __var __error; then return; fi
	# resolve uv now, while the PATH is still intact - a later sync can run
	# at a moment when the env providing uv is held by this very plugin
	_BASHY_UV_BIN=$(type -P uv)
	_bashy_prompt_register prompt_uv
	__var=0
}

# Undo the activation in the running shell, for bashy_deactivate.
function _deactivate_prompt_uv() {
	_bashy_prompt_deregister prompt_uv
	_prompt_uv_leave
}

register_interactive _activate_prompt_uv _deactivate_prompt_uv
